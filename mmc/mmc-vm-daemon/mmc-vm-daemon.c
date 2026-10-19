/*
 * MMC VM Daemon
 * This daemon runs inside a QEMU/KVM virtual machine and handles communication
 * through a virtual serial device (virtio-serial).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <getopt.h>
#include <errno.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include "../include/mmc_common.h"
#include "../include/mmc_config.h"

/* Global variables */
static volatile int running = 1;  /* Controls the main loop */
static mmc_vm_config_t config;   /* Configuration data */

/* Signal handler for graceful shutdown
 * Handles SIGTERM and SIGINT by setting running to 0
 */
static void signal_handler(int signo) {
    if (signo == SIGTERM || signo == SIGINT) {
        running = 0;
    }
}

/* Opens the virtual serial device for reading and writing
 * Returns: File descriptor on success, -1 on failure
 */
static int open_serial_device(const char *device) {
    int fd = open(device, O_RDWR | O_NOCTTY);
    if (fd < 0) {
        mmc_log_error(config.log_file, "Failed to open serial device %s: %s", 
                      device, strerror(errno));
        return -1;
    }
    return fd;
}

/* Writes a message to the serial device
 * Automatically adds a newline character at the end
 */
static void write_message_to_serial(int fd, const char *message) {
    char buffer[MMC_MAX_MSG_SIZE + 2];  // +2 for \n and \0
    snprintf(buffer, sizeof(buffer), "%.*s\n", MMC_MAX_MSG_SIZE, message);
    ssize_t bytes_written = write(fd, buffer, strlen(buffer));
    if (bytes_written < 0) {
        mmc_log_error(config.log_file, "Failed to write to serial device: %s", 
                      strerror(errno));
    }
}

/* Envoie un message TCP à l'adresse et au port configurés */
static void send_tcp_message(const char *ip, int port, const char *message, int serial_fd) {
    struct timeval start, end;
    gettimeofday(&start, NULL);
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        mmc_log_error(config.log_file, "Failed to create TCP socket: %s", strerror(errno));
        return;
    }
    struct sockaddr_in dest_addr;
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(port);
    if (inet_pton(AF_INET, ip, &dest_addr.sin_addr) != 1) {
        mmc_log_error(config.log_file, "Invalid remote IP address: %s", ip);
        close(sockfd);
        return;
    }
    if (connect(sockfd, (struct sockaddr*)&dest_addr, sizeof(dest_addr)) < 0) {
        mmc_log_error(config.log_file, "Failed to connect to TCP server %s:%d: %s", ip, port, strerror(errno));
        close(sockfd);
        return;
    }
    // Timeout de lecture paramétrable
    struct timeval timeout;
    timeout.tv_sec = config.tcp_response_timeout > 0 ? config.tcp_response_timeout : 10;
    timeout.tv_usec = 0;
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    gettimeofday(&end, NULL);
    long duration_ms = (end.tv_sec - start.tv_sec) * 1000L + (end.tv_usec - start.tv_usec) / 1000L;
    mmc_log(config.log_file, "Connected to TCP server %s:%d (connection time: %ld ms)", ip, port, duration_ms);
    // Préparer le message avec \r\n
    char sendbuf[MMC_MAX_MSG_SIZE + 3];
    size_t msglen = strlen(message);
    if (msglen > MMC_MAX_MSG_SIZE) msglen = MMC_MAX_MSG_SIZE;
    memcpy(sendbuf, message, msglen);
    sendbuf[msglen] = '\r';
    sendbuf[msglen + 1] = '\n';
    sendbuf[msglen + 2] = '\0';

    ssize_t sent = send(sockfd, sendbuf, msglen + 2, 0);
    if (sent < 0) {
        mmc_log_error(config.log_file, "Failed to send TCP message: %s", strerror(errno));
    } else {
        mmc_log(config.log_file, "Sent %zd bytes to TCP server %s:%d", sent, ip, port);
        // Lecture de la réponse du serveur (attente bloquante, lecture jusqu'à fermeture ou timeout)
        char response[4096];
        size_t total_received = 0;
        ssize_t received;
        while ((received = recv(sockfd, response + total_received, sizeof(response) - 1 - total_received, 0)) > 0) {
            total_received += received;
            if (total_received >= sizeof(response) - 1) break;
        }
        if (total_received > 0) {
            response[total_received] = '\0';
            mmc_log(config.log_file, "Received TCP response (%zu bytes): %s", total_received, response);
            write_message_to_serial(serial_fd, response);
            mmc_log(config.log_file, "Sent TCP response to serial device: %s", response);
        } else if (received == 0) {
            mmc_log(config.log_file, "TCP server closed connection without sending a response");
        } else {
            mmc_log_error(config.log_file, "Error receiving TCP response or timeout: %s", strerror(errno));
        }
    }
    close(sockfd);
}

/* Fonction utilitaire pour retirer un caractère de retour à la fin
 * d'une chaîne, et utilise-la uniquement pour le log du message reçu (pas pour l'envoi).
 */
static void strip_one_trailing_return(char *str) {
    size_t len = strlen(str);
    if (len > 0 && (str[len-1] == '\n' || str[len-1] == '\r')) {
        str[len-1] = '\0';
    }
}

/* Main function
 * Handles command line arguments, initializes the daemon,
 * and runs the main message processing loop
 */
int main(int argc, char *argv[]) {
    int opt;
    char *config_file = NULL;
    int serial_fd;
    char buffer[MMC_MAX_MSG_SIZE];
    ssize_t bytes_read;

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
        config_file = mmc_config_get_default_path("mmc-vm-daemon");
    }

    /* Load configuration */
    if (mmc_config_load_vm(config_file, &config) != MMC_SUCCESS) {
        fprintf(stderr, "Failed to load configuration\n");
        return 1;
    }

    /* Set up signal handlers for graceful shutdown */
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);

    mmc_log(config.log_file, "Starting MMC VM daemon");

    /* Open the serial device */
    serial_fd = open_serial_device(config.serial_device);
    if (serial_fd < 0) {
        return 1;
    }

    mmc_log(config.log_file, "Successfully opened serial device %s", config.serial_device);

    /* Main processing loop */
    while (running) {
        bytes_read = read(serial_fd, buffer, sizeof(buffer) - 1);
        if (bytes_read > 0) {
            buffer[bytes_read] = '\0';
            /* Remove trailing newline if present */
            if (bytes_read > 0 && buffer[bytes_read - 1] == '\n') {
                buffer[bytes_read - 1] = '\0';
            }
            char logbuf[MMC_MAX_MSG_SIZE+1];
            strncpy(logbuf, buffer, MMC_MAX_MSG_SIZE);
            logbuf[MMC_MAX_MSG_SIZE] = '\0';
            strip_one_trailing_return(logbuf);
            mmc_log(config.log_file, "Received message: %s", logbuf);
            
            /* Check if this is a special command */
            if (strcmp(buffer, "display_db") == 0) {
                /* Execute display_db.sh script */
                FILE *fp = popen("/usr/bin/display_db.sh", "r");
                if (fp == NULL) {
                    mmc_log_error(config.log_file, "Failed to execute display_db.sh: %s", strerror(errno));
                    char error_msg[] = "Error: Failed to execute display_db.sh";
                    write_message_to_serial(serial_fd, error_msg);
                } else {
                    char script_output[4096];
                    size_t total_read = 0;
                    char line[1024];
                    
                    while (fgets(line, sizeof(line), fp) != NULL && total_read < sizeof(script_output) - 1) {
                        size_t line_len = strlen(line);
                        if (total_read + line_len < sizeof(script_output) - 1) {
                            strcpy(script_output + total_read, line);
                            total_read += line_len;
                        }
                    }
                    script_output[total_read] = '\0';
                    
                    int status = pclose(fp);
                    if (status == 0) {
                        mmc_log(config.log_file, "display_db.sh executed successfully");
                        write_message_to_serial(serial_fd, script_output);
                    } else {
                        mmc_log_error(config.log_file, "display_db.sh failed with status %d", status);
                        char error_msg[256];
                        snprintf(error_msg, sizeof(error_msg), "Error: display_db.sh failed with status %d", status);
                        write_message_to_serial(serial_fd, error_msg);
                    }
                }
            } else {
                /* Regular message - forward to TCP server */
                send_tcp_message(config.remote_ip, config.remote_port, buffer, serial_fd);
            }
        } else if (bytes_read < 0 && errno != EAGAIN) {
            mmc_log_error(config.log_file, "Error reading from serial device: %s", 
                         strerror(errno));
            break;
        }
    }

    /* Cleanup and shutdown */
    close(serial_fd);
    mmc_log(config.log_file, "Shutting down MMC VM daemon");
    return 0;
} 