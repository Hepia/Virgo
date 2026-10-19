/**
 * @file mmc_config.h
 * @brief Configuration management for the MMC (Message to Machine Communication) system
 *
 * This header file defines the configuration structures and functions for all MMC components:
 * - VM daemon configuration (serial device settings)
 * - Host daemon configuration (network and socket settings)
 * - CLI configuration (network interface settings)
 * - Configuration loading and utility functions
 */

#ifndef MMC_CONFIG_H
#define MMC_CONFIG_H

#include <json-c/json.h>
#include "mmc_common.h"

/**
 * @brief Configuration structure for the VM daemon
 *
 * Contains settings specific to the daemon running inside virtual machines
 */
typedef struct {
    char serial_device[MMC_MAX_PATH_SIZE];    /**< Path to the virtio-serial device */
    char log_file[MMC_MAX_PATH_SIZE];         /**< Path to the log file */
    char remote_ip[MMC_MAX_PATH_SIZE];        /**< Remote IP address to send messages to */
    int remote_port;                          /**< Remote port to send messages to */
    int tcp_response_timeout;                 /**< Timeout in seconds for TCP response (default: 10) */
} mmc_vm_config_t;

/**
 * @brief Configuration structure for the host daemon
 *
 * Contains settings specific to the daemon running on host machines
 */
typedef struct {
    char unix_socket_path[MMC_MAX_PATH_SIZE];    /**< Path to the Unix domain socket */
    char multicast_group[MMC_MAX_PATH_SIZE];     /**< IPv6 multicast group address */
    char listen_interface[MMC_MAX_PATH_SIZE];    /**< Network interface to listen on */
    char log_file[MMC_MAX_PATH_SIZE];           /**< Path to the log file */
    char response_message[MMC_MAX_MSG_SIZE];    /**< Custom response message */
    char hash[MMC_MAX_HASH_SIZE];              /**< Authentication hash (64 hex chars + null) */
    int unix_socket_retry_delay;                /**< Delay in seconds between Unix socket connection attempts (must be > 0) */
    int unix_socket_retry_count;                /**< Number of connection attempts (0 = infinite, >0 = max attempts, <0 = invalid) */
} mmc_host_config_t;

/**
 * @brief Configuration structure for the CLI
 *
 * Contains settings specific to the command-line interface
 */
typedef struct {
    char multicast_group[MMC_MAX_PATH_SIZE];    /**< IPv6 multicast group address */
    int port;                                   /**< Network port number */
    char interface[MMC_MAX_PATH_SIZE];         /**< Network interface to use */
} mmc_cli_config_t;

/**
 * @brief Load configuration for the VM daemon from a JSON file
 *
 * @param config_file Path to the configuration file
 * @param config Pointer to the configuration structure to fill
 * @return MMC_SUCCESS on success, error code on failure
 */
mmc_error_t mmc_config_load_vm(const char *config_file, mmc_vm_config_t *config);

/**
 * @brief Load configuration for the host daemon from a JSON file
 *
 * @param config_file Path to the configuration file
 * @param config Pointer to the configuration structure to fill
 * @return MMC_SUCCESS on success, error code on failure
 */
mmc_error_t mmc_config_load_host(const char *config_file, mmc_host_config_t *config);

/**
 * @brief Load configuration for the CLI from a JSON file
 *
 * @param config_file Path to the configuration file
 * @param config Pointer to the configuration structure to fill
 * @return MMC_SUCCESS on success, error code on failure
 */
mmc_error_t mmc_config_load_cli(const char *config_file, mmc_cli_config_t *config);

/**
 * @brief Print usage information for MMC programs
 *
 * Displays command-line options and their descriptions
 *
 * @param program_name Name of the program (used in the usage message)
 */
void mmc_config_print_usage(const char *program_name);

/**
 * @brief Get the default configuration file path for an MMC program
 *
 * Constructs the path as /etc/mmc/<program_name>-config.json
 *
 * @param program_name Name of the program
 * @return Pointer to a static buffer containing the path
 */
char *mmc_config_get_default_path(const char *program_name);

/**
 * @brief Update the hash value in the host daemon configuration file
 *
 * @param config_file Path to the configuration file
 * @param new_hash The new hash value to write
 * @return MMC_SUCCESS on success, MMC_ERROR_CONFIG on failure
 */
mmc_error_t mmc_config_update_hash(const char *config_file, const char *new_hash);

#endif /* MMC_CONFIG_H */ 