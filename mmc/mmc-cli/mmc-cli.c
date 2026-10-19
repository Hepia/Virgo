/*
 * MMC Command Line Interface
 * This program provides a command-line interface for sending messages to VMs
 * through the MMC system. It handles host authentication and message delivery
 * using IPv6 multicast communication.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <getopt.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <readline/readline.h>
#include <readline/history.h>
#include "../include/mmc_common.h"
#include "../include/mmc_config.h"

#define MAX_HOSTS 10        /* Maximum number of connected hosts */
#define COMMAND_SIZE 1024   /* Maximum size of a command */

/* Structure to track connected hosts */
typedef struct {
    char hash[MMC_MAX_HASH_SIZE + 1];  /* Authentication hash + null terminator */
    char ipv6[INET6_ADDRSTRLEN];      /* IPv6 address */
} host_info_t;

/* Global variables */
static volatile int running = 1;          /* Controls the main loop */
static mmc_cli_config_t config;         /* Configuration data */
static host_info_t hosts[MAX_HOSTS];    /* Array of connected hosts */
static int num_hosts = 0;               /* Number of connected hosts */
static int multicast_fd = -1;          /* Multicast socket file descriptor */
static struct sockaddr_in6 multicast_addr;  /* Multicast address structure */

/* Signal handler for graceful shutdown
 * Handles SIGTERM and SIGINT by cleaning up readline
 */
static void signal_handler(int signo) {
    if (signo == SIGTERM || signo == SIGINT) {
        running = 0;
        printf("\nExiting...\n");
        rl_callback_handler_remove();
    }
}

/* Creates and configures the multicast socket
 * Returns: Socket file descriptor on success, -1 on failure
 */
static int setup_multicast_socket(void) {
    int fd;
    struct ipv6_mreq mreq;
    int yes = 1;

    /* Create IPv6 UDP socket */
    fd = socket(AF_INET6, SOCK_DGRAM, 0);
    if (fd < 0) {
        perror("Failed to create socket");
        return -1;
    }

    /* Enable address reuse */
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) < 0) {
        perror("Failed to set SO_REUSEADDR");
        close(fd);
        return -1;
    }

    /* Set up multicast address */
    memset(&multicast_addr, 0, sizeof(multicast_addr));
    multicast_addr.sin6_family = AF_INET6;
    multicast_addr.sin6_port = htons(config.port);
    if (inet_pton(AF_INET6, config.multicast_group, &multicast_addr.sin6_addr) != 1) {
        fprintf(stderr, "Invalid multicast group address\n");
        close(fd);
        return -1;
    }

    /* Bind to any address but specific port */
    struct sockaddr_in6 addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin6_family = AF_INET6;
    addr.sin6_port = htons(config.port);
    addr.sin6_addr = in6addr_any;

    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("Failed to bind socket");
        close(fd);
        return -1;
    }

    /* Join multicast group on specified interface */
    memset(&mreq, 0, sizeof(mreq));
    memcpy(&mreq.ipv6mr_multiaddr, &multicast_addr.sin6_addr, sizeof(struct in6_addr));
    mreq.ipv6mr_interface = if_nametoindex(config.interface);
    if (mreq.ipv6mr_interface == 0) {
        fprintf(stderr, "Invalid interface name: %s\n", config.interface);
        close(fd);
        return -1;
    }

    if (setsockopt(fd, IPPROTO_IPV6, IPV6_JOIN_GROUP, &mreq, sizeof(mreq)) < 0) {
        perror("Failed to join multicast group");
        close(fd);
        return -1;
    }

    return fd;
}

/* Sends a message to the multicast group */
static void send_multicast(const char *message) {
    if (sendto(multicast_fd, message, strlen(message), 0,
               (struct sockaddr*)&multicast_addr, sizeof(multicast_addr)) < 0) {
        perror("Failed to send multicast message");
    }
}

/* Adds a new host to the tracking array
 * Checks for duplicates and array size limits
 */
static void add_host(const char *hash, const char *ipv6) {
    if (num_hosts >= MAX_HOSTS) {
        printf("Maximum number of hosts reached\n");
        return;
    }

    /* Check if host already exists */
    for (int i = 0; i < num_hosts; i++) {
        if (strcmp(hosts[i].hash, hash) == 0 || strcmp(hosts[i].ipv6, ipv6) == 0) {
            return;  /* Host already exists with same hash or IP */
        }
    }

    /* Vérification de la taille du hash */
    size_t hash_len = strlen(hash);
    if (hash_len != 64) {
        printf("Hash invalide : %zu caractères (doit être exactement 64)\n", hash_len);
        return;
    }

    /* Vérification de la taille de l'IPv6 */
    size_t ipv6_len = strlen(ipv6);
    if (ipv6_len >= INET6_ADDRSTRLEN) {
        printf("IPv6 address too long: %zu bytes (max %d)\n", ipv6_len, INET6_ADDRSTRLEN - 1);
        return;
    }

    /* Copie du hash avec son caractère nul */
    memcpy(hosts[num_hosts].hash, hash, 64);
    hosts[num_hosts].hash[64] = '\0';
    
    /* Copie de l'adresse IPv6 */
    memcpy(hosts[num_hosts].ipv6, ipv6, ipv6_len);
    hosts[num_hosts].ipv6[ipv6_len] = '\0';

    num_hosts++;
    printf("New host added: %s\n", ipv6);
}

/* Removes a host from the tracking array
 * Maintains array continuity by shifting remaining elements
 */
static void remove_host(const char *hash) {
    for (int i = 0; i < num_hosts; i++) {
        if (strcmp(hosts[i].hash, hash) == 0) {
            if (i < num_hosts - 1) {
                memmove(&hosts[i], &hosts[i + 1], 
                        (num_hosts - i - 1) * sizeof(host_info_t));
            }
            num_hosts--;
            printf("Host removed: %s\n", hash);
            return;
        }
    }
}

/* Handles hello messages from host daemons
 * Validates the hash and sends welcome response
 */
static void handle_hello_message(const char *message, const char *peer_ip) {
    printf("Debug: Received message: '%s'\n", message);
    
    const char *recv_hash = message + strlen(MMC_MSG_HELLO);
    printf("Debug: Extracted hash: '%s'\n", recv_hash);
    printf("Debug: Hash length: %zu\n", strlen(recv_hash));
    
    /* Validate the received hash */
    if (!mmc_validate_hash(recv_hash)) {
        printf("Received invalid hash from %s\n", peer_ip);
        return;
    }

    add_host(recv_hash, peer_ip);
    
    /* Send welcome message */
    char welcome_msg[MMC_MAX_MSG_SIZE];
    size_t welcome_prefix_len = strlen(MMC_MSG_WELCOME);
    size_t hash_len = strlen(recv_hash);
    
    /* Vérification que le message complet tiendra dans le buffer */
    if (welcome_prefix_len + hash_len >= MMC_MAX_MSG_SIZE) {
        printf("Welcome message would be too long: %zu bytes (max %d)\n", 
               welcome_prefix_len + hash_len, MMC_MAX_MSG_SIZE - 1);
        return;
    }
    
    /* Construction sécurisée du message */
    memcpy(welcome_msg, MMC_MSG_WELCOME, welcome_prefix_len);
    memcpy(welcome_msg + welcome_prefix_len, recv_hash, hash_len);
    welcome_msg[welcome_prefix_len + hash_len] = '\0';
    
    send_multicast(welcome_msg);
    printf("Sent welcome message to %s\n", peer_ip);
}

/* Fonction utilitaire pour retirer trois caractères de retour à la fin
 */
static void strip_three_trailing_returns(char *str) {
    for (int i = 0; i < 3; ++i) {
        size_t len = strlen(str);
        if (len > 0 && (str[len-1] == '\n' || str[len-1] == '\r')) {
            str[len-1] = '\0';
        }
    }
}

/* Processes user commands
 * Supports: SEND, LIST, EXIT/QUIT, HELP
 */
static void handle_command(char *command) {
    char buffer[COMMAND_SIZE];

    if (strncasecmp(command, "SEND ", 5) == 0) {
        const char *message = command + 5;
        size_t msg_len = strlen(message);
        
        if (msg_len == 0) {
            printf("Error: Empty message\n");
            return;
        }
        
        if (msg_len > MMC_MAX_MSG_SIZE - strlen(MMC_MSG_SEND) - 1) {
            printf("Error: Message too long (max %zu characters)\n", 
                   MMC_MAX_MSG_SIZE - strlen(MMC_MSG_SEND) - 1);
            return;
        }

        snprintf(buffer, sizeof(buffer), "%s%s", MMC_MSG_SEND, message);
        send_multicast(buffer);
        printf("Message sent\n");
    }
    else if (strcasecmp(command, "LIST") == 0) {
        printf("Connected hosts (%d):\n", num_hosts);
        for (int i = 0; i < num_hosts; i++) {
            printf("%d. Hash: %s, IPv6: %s\n", i + 1, hosts[i].hash, hosts[i].ipv6);
        }
    }
    else if (strcasecmp(command, "EXIT") == 0 || strcasecmp(command, "QUIT") == 0) {
        if (num_hosts > 0) {
            send_multicast(MMC_MSG_END);
            printf("Notified %d host(s) of disconnection\n", num_hosts);
        }
        printf("Goodbye!\n");
        running = 0;
    }
    else if (strcasecmp(command, "HELP") == 0) {
        printf("Available commands:\n");
        printf("  SEND <message>  Send a message to all connected VMs (max %zu chars)\n",
               MMC_MAX_MSG_SIZE - strlen(MMC_MSG_SEND) - 1);
        printf("  LIST           List all connected hosts\n");
        printf("  DISPLAY_DB     Execute display_db.sh script in connected VMs\n");
        printf("  HELP           Show this help message\n");
        printf("  EXIT or QUIT   Exit the program\n");
    }
    else if (strcasecmp(command, "DISPLAY_DB") == 0) {
        snprintf(buffer, sizeof(buffer), "%s%s", MMC_MSG_SPECIAL, "display_db");
        send_multicast(buffer);
        printf("Display DB command sent to all connected VMs\n");
    }
    else {
        printf("Unknown command. Type 'HELP' for available commands.\n");
    }
}

/* Readline callback function
 * Processes user input and maintains command history
 */
static void command_callback(char *line) {
    if (line == NULL) {
        printf("\n");
        running = 0;
        return;
    }

    if (*line != '\0') {
        add_history(line);
        handle_command(line);
    }

    free(line);
    if (running) {
        rl_callback_handler_install("mmc> ", command_callback);
    }
}

/* Main function
 * Handles command line arguments, initializes the CLI,
 * and runs the main processing loop
 */
int main(int argc, char *argv[]) {
    int opt;
    char *config_file = NULL;
    fd_set read_fds;
    struct timeval tv;
    char buffer[COMMAND_SIZE];
    struct sockaddr_in6 peer_addr;
    socklen_t peer_addr_len;

    /* Command line options */
    struct option long_options[] = {
        {"config", required_argument, 0, 'c'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    /* Parse command line arguments */
    while ((opt = getopt_long(argc, argv, "c:h", long_options, NULL)) != -1) {
        switch (opt) {
            case 'c':
                config_file = optarg;
                break;
            case 'h':
                mmc_config_print_usage(argv[0]);
                return 0;
            default:
                mmc_config_print_usage(argv[0]);
                return 1;
        }
    }

    /* Use default config path if none specified */
    if (!config_file) {
        config_file = mmc_config_get_default_path("mmc-cli");
    }

    /* Load configuration */
    if (mmc_config_load_cli(config_file, &config) != MMC_SUCCESS) {
        fprintf(stderr, "Failed to load configuration\n");
        return 1;
    }

    /* Set up signal handlers */
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);

    /* Initialize multicast socket */
    multicast_fd = setup_multicast_socket();
    if (multicast_fd < 0) {
        return 1;
    }

    printf("MMC CLI started. Type 'HELP' for available commands.\n");
    rl_callback_handler_install("mmc> ", command_callback);

    /* Main processing loop */
    while (running) {
        FD_ZERO(&read_fds);
        FD_SET(STDIN_FILENO, &read_fds);
        FD_SET(multicast_fd, &read_fds);

        tv.tv_sec = 0;
        tv.tv_usec = 100000;  /* 100ms timeout */

        int max_fd = (multicast_fd > STDIN_FILENO) ? multicast_fd : STDIN_FILENO;
        int ret = select(max_fd + 1, &read_fds, NULL, NULL, &tv);

        if (ret < 0) {
            if (errno == EINTR) continue;
            perror("select() failed");
            break;
        }

        /* Handle user input */
        if (FD_ISSET(STDIN_FILENO, &read_fds)) {
            rl_callback_read_char();
        }

        /* Handle network messages */
        if (FD_ISSET(multicast_fd, &read_fds)) {
            peer_addr_len = sizeof(peer_addr);
            ssize_t bytes = recvfrom(multicast_fd, buffer, sizeof(buffer) - 1, 0,
                                   (struct sockaddr*)&peer_addr, &peer_addr_len);
            if (bytes > 0) {
                buffer[bytes] = '\0';
                char peer_ip[INET6_ADDRSTRLEN];
                inet_ntop(AF_INET6, &peer_addr.sin6_addr, peer_ip, INET6_ADDRSTRLEN);

                if (strncmp(buffer, MMC_MSG_HELLO, strlen(MMC_MSG_HELLO)) == 0) {
                    handle_hello_message(buffer, peer_ip);
                }
                else if (strncmp(buffer, MMC_MSG_END, strlen(MMC_MSG_END)) == 0) {
                    /* Remove host that sent END message */
                    for (int i = 0; i < num_hosts; i++) {
                        if (strcmp(hosts[i].ipv6, peer_ip) == 0) {
                            remove_host(hosts[i].hash);
                            break;
                        }
                    }
                }
                else if (strncmp(buffer, MMC_MSG_RESPONSE, strlen(MMC_MSG_RESPONSE)) == 0) {
                    // Gestion des messages de réponse
                    const char *ptr = buffer + strlen(MMC_MSG_RESPONSE);
                    char hash[MMC_MAX_HASH_SIZE];
                    strncpy(hash, ptr, 64);
                    hash[64] = '\0';
                    const char *msg = ptr + 64;
                    int found = 0;
                    for (int i = 0; i < num_hosts; i++) {
                        if (strcmp(hosts[i].hash, hash) == 0) {
                            found = 1;
                            break;
                        }
                    }
                    if (found) {
                        char msgbuf[COMMAND_SIZE];
                        strncpy(msgbuf, msg, COMMAND_SIZE-1);
                        msgbuf[COMMAND_SIZE-1] = '\0';
                        strip_three_trailing_returns(msgbuf);
                        printf("[MMC-RESPONSE][%s]: %s\n", hash, msgbuf);
                    } else {
                        printf("[MMC-ERROR] Réponse reçue d'un host non enregistré (hash: %s)\n", hash);
                    }
                }
            }
        }
    }

    /* Cleanup and shutdown */
    close(multicast_fd);
    rl_callback_handler_remove();
    printf("\n");
    return 0;
} 