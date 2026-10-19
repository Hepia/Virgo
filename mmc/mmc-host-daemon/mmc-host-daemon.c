/*
 * MMC Host Daemon
 * This daemon runs on the host machine and relays messages between
 * the network (IPv6 multicast) and the VM through a Unix socket.
 * It implements the authentication protocol and message forwarding.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <getopt.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include "../include/mmc_common.h"
#include "../include/mmc_config.h"

#define BUFFER_SIZE 1024
#define HELLO_RETRY_INTERVAL 5  /* Seconds between hello message retries */

/* Global variables */
static volatile int running = 1;          /* Controls the main loop */
static mmc_host_config_t config;         /* Configuration data */
static char current_hash[MMC_MAX_HASH_SIZE] = {0};  /* Current authentication hash */
static int is_authorized = 0;            /* Authorization state */
static int multicast_fd = -1;           /* Multicast socket file descriptor */
static struct sockaddr_in6 multicast_addr;  /* Multicast address structure */
static time_t last_hello_time = 0;
static char *config_file_path = NULL;
static int unix_fd = -1;

/* Signal handler for graceful shutdown
 * Handles SIGTERM and SIGINT by setting running to 0
 */
static void signal_handler(int signo) {
    if (signo == SIGTERM || signo == SIGINT) {
        running = 0;
    }
}

/* Creates and connects to the Unix domain socket
 * Returns: Socket file descriptor on success, -1 on failure
 */
static int create_unix_socket(const char *path) {
    int fd;
    struct sockaddr_un addr;
    size_t path_len = strlen(path);

    /* Vérification de la longueur du chemin */
    if (path_len >= sizeof(addr.sun_path)) {
        mmc_log_error(config.log_file, "Unix socket path too long: %zu bytes (max %zu)",
                      path_len, sizeof(addr.sun_path) - 1);
        return -1;
    }

    fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        mmc_log_error(config.log_file, "Failed to create Unix socket: %s", strerror(errno));
        return -1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    memcpy(addr.sun_path, path, path_len);
    addr.sun_path[path_len] = '\0';

    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        mmc_log_error(config.log_file, "Failed to connect to Unix socket %s: %s", 
                      path, strerror(errno));
        close(fd);
        return -1;
    }

    return fd;
}

/* Creates and configures the multicast socket
 * Returns: Socket file descriptor on success, -1 on failure
 */
static int create_multicast_socket(const char *group, const char *interface, int port) {
    int fd;
    struct ipv6_mreq mreq;
    int yes = 1;

    /* Create IPv6 UDP socket */
    fd = socket(AF_INET6, SOCK_DGRAM, 0);
    if (fd < 0) {
        mmc_log_error(config.log_file, "Failed to create IPv6 socket: %s", strerror(errno));
        return -1;
    }

    /* Enable address reuse */
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) < 0) {
        mmc_log_error(config.log_file, "Failed to set SO_REUSEADDR: %s", strerror(errno));
        close(fd);
        return -1;
    }

    /* Set up multicast address */
    memset(&multicast_addr, 0, sizeof(multicast_addr));
    multicast_addr.sin6_family = AF_INET6;
    multicast_addr.sin6_port = htons(port);
    if (inet_pton(AF_INET6, group, &multicast_addr.sin6_addr) != 1) {
        mmc_log_error(config.log_file, "Invalid multicast group address");
        close(fd);
        return -1;
    }

    /* Bind to any address */
    struct sockaddr_in6 addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin6_family = AF_INET6;
    addr.sin6_port = htons(port);
    addr.sin6_addr = in6addr_any;

    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        mmc_log_error(config.log_file, "Failed to bind socket: %s", strerror(errno));
        close(fd);
        return -1;
    }

    /* Join multicast group on specified interface */
    memset(&mreq, 0, sizeof(mreq));
    memcpy(&mreq.ipv6mr_multiaddr, &multicast_addr.sin6_addr, sizeof(struct in6_addr));
    mreq.ipv6mr_interface = if_nametoindex(interface);
    if (mreq.ipv6mr_interface == 0) {
        mmc_log_error(config.log_file, "Invalid interface name: %s", interface);
        close(fd);
        return -1;
    }

    if (setsockopt(fd, IPPROTO_IPV6, IPV6_JOIN_GROUP, &mreq, sizeof(mreq)) < 0) {
        mmc_log_error(config.log_file, "Failed to join multicast group: %s", strerror(errno));
        close(fd);
        return -1;
    }

    return fd;
}

/* Sends a message to the multicast group */
static void send_multicast(const char *message) {
    if (sendto(multicast_fd, message, strlen(message), 0,
               (struct sockaddr*)&multicast_addr, sizeof(multicast_addr)) < 0) {
        mmc_log_error(config.log_file, "Failed to send multicast message: %s", strerror(errno));
    }
}

/* Initialize or load the node's hash from configuration
 * Returns: 0 on success, -1 on failure
 */
static int initialize_node_hash(void) {
    /* Check if we need to generate a new hash */
    if (strcmp(config.hash, "undef") == 0) {
        /* Generate new hash */
        char *new_hash = mmc_generate_hash();
        if (!new_hash) {
            mmc_log_error(config.log_file, "Failed to generate hash");
            return -1;
        }

        /* Update configuration file with new hash */
        if (mmc_config_update_hash(config_file_path, new_hash) != MMC_SUCCESS) {
            mmc_log_error(config.log_file, "Failed to update configuration with new hash");
            free(new_hash);
            return -1;
        }

        /* Update current hash */
        strncpy(current_hash, new_hash, MMC_MAX_HASH_SIZE - 1);
        current_hash[MMC_MAX_HASH_SIZE - 1] = '\0';
        free(new_hash);
        mmc_log(config.log_file, "Generated and saved new hash: %s", current_hash);
    } else {
        /* Use existing hash from config */
        if (!mmc_validate_hash(config.hash)) {
            mmc_log_error(config.log_file, "Invalid hash in configuration file");
            return -1;
        }
        strncpy(current_hash, config.hash, MMC_MAX_HASH_SIZE - 1);
        current_hash[MMC_MAX_HASH_SIZE - 1] = '\0';
        mmc_log(config.log_file, "Using existing hash from config: %s", current_hash);
    }

    return 0;
}

/* Sends a hello message with the current hash to initiate authentication */
static void send_hello_message(void) {
    if (!is_authorized) {  /* N'envoie que si pas encore autorisé */
        char hello_msg[MMC_MAX_MSG_SIZE];
        snprintf(hello_msg, sizeof(hello_msg), "%s%s", MMC_MSG_HELLO, current_hash);
        send_multicast(hello_msg);
        last_hello_time = time(NULL);
        mmc_log(config.log_file, "Sent hello message with hash: %s", current_hash);
    }
}

/* Writes a message to the Unix socket with error handling
 * Ensures complete message is written by handling partial writes
 */
static void write_to_unix_socket(int fd, const char *message) {
    char buffer[MMC_MAX_MSG_SIZE + 2];  // +2 for \n and \0
    snprintf(buffer, sizeof(buffer), "%s\n", message);
    ssize_t total_written = 0;
    size_t remaining = strlen(buffer);
    while (remaining > 0) {
        ssize_t written = write(fd, buffer + total_written, remaining);
        if (written < 0) {
            if (errno == EINTR) continue;
            mmc_log_error(config.log_file, "Failed to write to Unix socket: %s (fd=%d)", strerror(errno), fd);
            if (errno == EPIPE || errno == ECONNRESET || errno == EBADF || errno == ENOTCONN) {
                mmc_log_error(config.log_file, "Unix socket closed or broken, will attempt to reconnect.");
                close(fd);
                unix_fd = -1;
            }
            return;
        }
        total_written += written;
        remaining -= written;
    }
    mmc_log(config.log_file, "Forwarded message to VM: %s", message);
}

/* Fonction utilitaire pour retirer deux caractères de retour à la fin
 * d'une chaîne, et utilise-la uniquement pour le log du message reçu du VM daemon (pas pour l'envoi).
 */
static void strip_two_trailing_returns(char *str) {
    for (int i = 0; i < 2; ++i) {
        size_t len = strlen(str);
        if (len > 0 && (str[len-1] == '\n' || str[len-1] == '\r')) {
            str[len-1] = '\0';
        }
    }
}

/* Handles incoming multicast messages
 * Processes authentication messages and forwards valid messages to VM
 */
static void handle_multicast_message(int unix_fd, const char *message, size_t length) {
    /* Ignore les messages si le descripteur de socket Unix est invalide */
    if (unix_fd < 0) {
        return;
    }

    /* Ignore nos propres messages hello */
    if (strncmp(message, MMC_MSG_HELLO, strlen(MMC_MSG_HELLO)) == 0) {
        const char *msg_hash = message + strlen(MMC_MSG_HELLO);
        if (strcmp(msg_hash, current_hash) == 0) {
            return;  /* C'est notre propre message hello */
        }
        return;  /* On ignore tous les messages hello */
    }

    /* Traitement des messages welcome */
    if (strncmp(message, MMC_MSG_WELCOME, strlen(MMC_MSG_WELCOME)) == 0) {
        const char *welcome_hash = message + strlen(MMC_MSG_WELCOME);
        
        /* Validate the received hash */
        if (!mmc_validate_hash(welcome_hash)) {
            mmc_log_error(config.log_file, "Received invalid welcome hash");
            return;
        }

        /* Vérifie si le hash correspond à notre hash actuel */
        if (strcmp(current_hash, welcome_hash) == 0) {
            if (!is_authorized) {  /* Ne log que si c'est un changement d'état */
                is_authorized = 1;
                mmc_log(config.log_file, "Authorization successful with hash: %s", current_hash);
            }
        }
        return;  /* Ne pas transmettre les messages welcome au VM daemon */
    }

    /* Traitement du message END */
    if (strcmp(message, MMC_MSG_END) == 0) {
        is_authorized = 0;
        mmc_log(config.log_file, "Received END message, resetting authorization");
        return;  /* Ne pas transmettre les messages END au VM daemon */
    }

    /* Si nous sommes autorisés et que c'est un message SEND, on le transmet au VM daemon */
    if (is_authorized && strncmp(message, MMC_MSG_SEND, strlen(MMC_MSG_SEND)) == 0) {
        const char *payload = message + strlen(MMC_MSG_SEND);
        write_to_unix_socket(unix_fd, payload);
    }
    
    /* Si nous sommes autorisés et que c'est un message SPEC, on le transmet au VM daemon */
    if (is_authorized && strncmp(message, MMC_MSG_SPECIAL, strlen(MMC_MSG_SPECIAL)) == 0) {
        const char *payload = message + strlen(MMC_MSG_SPECIAL);
        write_to_unix_socket(unix_fd, payload);
    }
}

/* Main function
 * Handles command line arguments, initializes the daemon,
 * and runs the main message processing loop
 */
int main(int argc, char *argv[]) {
    int opt;
    char *config_file = NULL;
    struct sockaddr_in6 peer_addr;
    socklen_t peer_addr_len = sizeof(peer_addr);
    char buffer[BUFFER_SIZE];
    fd_set read_fds;
    struct timeval tv;
    time_t current_time;

    /* Parse command line arguments */
    while ((opt = getopt(argc, argv, "c:h")) != -1) {
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

    /* Use default config if none specified */
    if (!config_file) {
        config_file = mmc_config_get_default_path("mmc-host-daemon");
    }

    /* Save config file path for later use */
    config_file_path = strdup(config_file);
    if (!config_file_path) {
        fprintf(stderr, "Failed to save config file path\n");
        return 1;
    }

    /* Load configuration */
    if (mmc_config_load_host(config_file, &config) != MMC_SUCCESS) {
        fprintf(stderr, "Failed to load configuration\n");
        free(config_file_path);
        return 1;
    }

    /* Initialize node hash */
    if (initialize_node_hash() != 0) {
        fprintf(stderr, "Failed to initialize node hash\n");
        free(config_file_path);
        return 1;
    }

    /* Set up signal handlers */
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);

    /* Initialize Unix socket avec retry */
    if (config.unix_socket_retry_delay <= 0) {
        mmc_log_error(config.log_file, "Invalid unix_socket_retry_delay (%d): must be > 0", config.unix_socket_retry_delay);
        free(config_file_path);
        return 1;
    }
    if (config.unix_socket_retry_count < 0) {
        mmc_log_error(config.log_file, "Invalid unix_socket_retry_count (%d): must be >= 0 (0 = infinite)", config.unix_socket_retry_count);
        free(config_file_path);
        return 1;
    }

    /* Initialize multicast socket */
    multicast_fd = create_multicast_socket(config.multicast_group, 
                                         config.listen_interface, 12345);
    if (multicast_fd < 0) {
        free(config_file_path);
        return 1;
    }

    /* Send initial hello message */
    send_hello_message();

    /* Main loop */
    while (running) {
        // Si la socket Unix est déconnectée, tenter de se reconnecter
        while (unix_fd < 0 && running) {
            int attempt = 0;
            while (1) {
                unix_fd = create_unix_socket(config.unix_socket_path);
                if (unix_fd >= 0) {
                    mmc_log(config.log_file, "Successfully reconnected to Unix socket.");
                    break;
                }
                attempt++;
                if (config.unix_socket_retry_count > 0 && attempt >= config.unix_socket_retry_count) {
                    mmc_log_error(config.log_file, "Failed to reconnect to Unix socket after %d attempts, aborting.", attempt);
                    running = 0;
                    break;
                }
                mmc_log(config.log_file, "Retrying Unix socket connection in %d second(s)... (attempt %d%s)",
                        config.unix_socket_retry_delay, attempt,
                        config.unix_socket_retry_count == 0 ? "/∞" : "");
                sleep(config.unix_socket_retry_delay);
            }
        }
        if (!running) break;

        FD_ZERO(&read_fds);
        FD_SET(multicast_fd, &read_fds);
        int max_fd = multicast_fd;
        if (unix_fd >= 0) {
            FD_SET(unix_fd, &read_fds);
            if (unix_fd > max_fd) max_fd = unix_fd;
        }

        /* Set timeout for select */
        tv.tv_sec = 1;  /* Check every second */
        tv.tv_usec = 0;

        int activity = select(max_fd + 1, &read_fds, NULL, NULL, &tv);
        
        if (activity < 0) {
            if (errno == EINTR) continue;  /* Interrupted by signal */
            mmc_log_error(config.log_file, "Select error: %s", strerror(errno));
            break;
        }

        current_time = time(NULL);

        /* Only send hello messages if we're not authorized and enough time has passed */
        if (!is_authorized && (current_time - last_hello_time) >= HELLO_RETRY_INTERVAL) {
            send_hello_message();
        }

        if (activity > 0 && FD_ISSET(multicast_fd, &read_fds)) {
            ssize_t received = recvfrom(multicast_fd, buffer, sizeof(buffer) - 1, 0,
                                      (struct sockaddr*)&peer_addr, &peer_addr_len);
            if (received > 0) {
                buffer[received] = '\0';
                handle_multicast_message(unix_fd, buffer, received);
            }
        }
        // Lecture sur la socket Unix (réponse du VM daemon)
        if (unix_fd >= 0 && activity > 0 && FD_ISSET(unix_fd, &read_fds)) {
            ssize_t n = read(unix_fd, buffer, sizeof(buffer) - 1);
            if (n > 0) {
                buffer[n] = '\0';
                char logbuf[BUFFER_SIZE];
                strncpy(logbuf, buffer, BUFFER_SIZE-1);
                logbuf[BUFFER_SIZE-1] = '\0';
                strip_two_trailing_returns(logbuf);
                mmc_log(config.log_file, "Received response from VM daemon: %s", logbuf);
                
                // Préparer et envoyer la réponse avec le hash
                char response[BUFFER_SIZE];
                size_t max_msg_len = sizeof(response) - strlen(MMC_MSG_RESPONSE) - strlen(current_hash) - 1;
                if (strlen(logbuf) > max_msg_len) {
                    mmc_log_error(config.log_file, "Response message too long, truncating to fit buffer");
                }
                snprintf(response, sizeof(response), "%s%s%.*s", MMC_MSG_RESPONSE, current_hash, (int)max_msg_len, logbuf);
                send_multicast(response);
                mmc_log(config.log_file, "Forwarded response with hash to multicast: %s", response);
            } else if (n == 0) {
                mmc_log_error(config.log_file, "Unix socket closed by VM daemon, will attempt to reconnect.");
                close(unix_fd);
                unix_fd = -1;
            } else if (n < 0 && errno != EINTR && errno != EAGAIN) {
                mmc_log_error(config.log_file, "Error reading from Unix socket: %s", strerror(errno));
                close(unix_fd);
                unix_fd = -1;
            }
        }
    }

    /* Cleanup */
    close(multicast_fd);
    free(config_file_path);
    return 0;
} 