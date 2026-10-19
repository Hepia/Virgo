/**
 * @file mmc_config.c
 * @brief Implementation of configuration management for the MMC system
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../include/mmc_config.h"

/**
 * @brief Internal helper function to load and parse a JSON configuration file
 *
 * This function:
 * 1. Validates the input file path
 * 2. Attempts to parse the file as JSON
 * 3. Returns the parsed JSON object or NULL on failure
 *
 * @param config_file Path to the JSON configuration file
 * @return Parsed json_object pointer or NULL on failure
 */
static json_object *load_json_file(const char *config_file) {
    json_object *json;
    
    if (!config_file) {
        return NULL;
    }

    json = json_object_from_file(config_file);
    if (!json) {
        fprintf(stderr, "Error loading config file: %s\n", json_util_get_last_err());
        return NULL;
    }

    return json;
}

/**
 * @brief Load configuration for the VM daemon from a JSON file
 *
 * Reads and parses the following fields:
 * - serial_device: Path to the virtio-serial device
 * - log_file: Path to the log file
 *
 * @param config_file Path to the configuration file
 * @param config Pointer to the configuration structure to fill
 * @return MMC_SUCCESS on success, MMC_ERROR_CONFIG on failure
 */
mmc_error_t mmc_config_load_vm(const char *config_file, mmc_vm_config_t *config) {
    json_object *json, *value;

    if (!config) return MMC_ERROR_CONFIG;

    json = load_json_file(config_file);
    if (!json) return MMC_ERROR_CONFIG;

    if (json_object_object_get_ex(json, "serial_device", &value))
        strncpy(config->serial_device, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    
    if (json_object_object_get_ex(json, "log_file", &value))
        strncpy(config->log_file, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    if (json_object_object_get_ex(json, "remote_ip", &value)) {
        strncpy(config->remote_ip, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
        config->remote_ip[MMC_MAX_PATH_SIZE - 1] = '\0';
    } else {
        strncpy(config->remote_ip, "127.0.0.1", MMC_MAX_PATH_SIZE);
        config->remote_ip[MMC_MAX_PATH_SIZE - 1] = '\0';
    }
    if (json_object_object_get_ex(json, "remote_port", &value)) {
        config->remote_port = json_object_get_int(value);
    } else {
        config->remote_port = 101;
    }
    if (json_object_object_get_ex(json, "tcp_response_timeout", &value)) {
        config->tcp_response_timeout = json_object_get_int(value);
    } else {
        config->tcp_response_timeout = 10;
    }

    json_object_put(json);
    return MMC_SUCCESS;
}

/**
 * @brief Load configuration for the host daemon from a JSON file
 *
 * Reads and parses the following fields:
 * - unix_socket_path: Path to the Unix domain socket
 * - multicast_group: IPv6 multicast group address
 * - listen_interface: Network interface to listen on
 * - log_file: Path to the log file
 * - response_message: Custom response message
 * - hash: Authentication hash
 * - unix_socket_retry_delay: Unix socket retry delay
 * - unix_socket_retry_count: Unix socket retry count
 *
 * @param config_file Path to the configuration file
 * @param config Pointer to the configuration structure to fill
 * @return MMC_SUCCESS on success, MMC_ERROR_CONFIG on failure
 */
mmc_error_t mmc_config_load_host(const char *config_file, mmc_host_config_t *config) {
    json_object *json, *value;

    if (!config) return MMC_ERROR_CONFIG;

    json = load_json_file(config_file);
    if (!json) return MMC_ERROR_CONFIG;

    if (json_object_object_get_ex(json, "unix_socket_path", &value))
        strncpy(config->unix_socket_path, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    
    if (json_object_object_get_ex(json, "multicast_group", &value))
        strncpy(config->multicast_group, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    
    if (json_object_object_get_ex(json, "listen_interface", &value))
        strncpy(config->listen_interface, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    
    if (json_object_object_get_ex(json, "log_file", &value))
        strncpy(config->log_file, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    
    if (json_object_object_get_ex(json, "response_message", &value))
        strncpy(config->response_message, json_object_get_string(value), MMC_MAX_MSG_SIZE - 1);
    
    if (json_object_object_get_ex(json, "hash", &value)) {
        strncpy(config->hash, json_object_get_string(value), MMC_MAX_HASH_SIZE - 1);
        config->hash[MMC_MAX_HASH_SIZE - 1] = '\0';
    }
    if (json_object_object_get_ex(json, "unix_socket_retry_delay", &value)) {
        config->unix_socket_retry_delay = json_object_get_int(value);
    } else {
        config->unix_socket_retry_delay = 2;
    }
    if (json_object_object_get_ex(json, "unix_socket_retry_count", &value)) {
        config->unix_socket_retry_count = json_object_get_int(value);
    } else {
        config->unix_socket_retry_count = 0;
    }

    json_object_put(json);
    return MMC_SUCCESS;
}

/**
 * @brief Load configuration for the CLI from a JSON file
 *
 * Reads and parses the following fields:
 * - multicast_group: IPv6 multicast group address
 * - interface: Network interface to use
 * - port: Network port number
 *
 * @param config_file Path to the configuration file
 * @param config Pointer to the configuration structure to fill
 * @return MMC_SUCCESS on success, MMC_ERROR_CONFIG on failure
 */
mmc_error_t mmc_config_load_cli(const char *config_file, mmc_cli_config_t *config) {
    json_object *json, *value;

    if (!config) return MMC_ERROR_CONFIG;

    json = load_json_file(config_file);
    if (!json) return MMC_ERROR_CONFIG;

    if (json_object_object_get_ex(json, "multicast_group", &value))
        strncpy(config->multicast_group, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    
    if (json_object_object_get_ex(json, "interface", &value))
        strncpy(config->interface, json_object_get_string(value), MMC_MAX_PATH_SIZE - 1);
    
    if (json_object_object_get_ex(json, "port", &value))
        config->port = json_object_get_int(value);

    json_object_put(json);
    return MMC_SUCCESS;
}

/**
 * @brief Print usage information for MMC programs
 *
 * Displays the following command-line options:
 * - -c, --config: Specify a configuration file
 * - -h, --help: Show help message
 *
 * @param program_name Name of the program (used in the usage message)
 */
void mmc_config_print_usage(const char *program_name) {
    printf("Usage: %s [-c config_file] [-h]\n", program_name);
    printf("Options:\n");
    printf("  -c, --config <file>  Specify configuration file\n");
    printf("  -h, --help          Show this help message\n");
}

/**
 * @brief Get the default configuration file path for an MMC program
 *
 * Constructs the path as /etc/mmc/<program_name>-config.json
 * The path is stored in a static buffer to avoid memory allocation.
 *
 * @param program_name Name of the program
 * @return Pointer to a static buffer containing the path
 */
char *mmc_config_get_default_path(const char *program_name) {
    static char path[MMC_MAX_PATH_SIZE];
    snprintf(path, MMC_MAX_PATH_SIZE, "/etc/mmc/%s-config.json", program_name);
    return path;
}

/**
 * @brief Update the hash value in the host daemon configuration file
 *
 * @param config_file Path to the configuration file
 * @param new_hash The new hash value to write
 * @return MMC_SUCCESS on success, MMC_ERROR_CONFIG on failure
 */
mmc_error_t mmc_config_update_hash(const char *config_file, const char *new_hash) {
    json_object *json, *hash_obj;
    const char *json_str;
    FILE *fp;

    if (!config_file || !new_hash) return MMC_ERROR_CONFIG;

    /* Load existing JSON */
    json = load_json_file(config_file);
    if (!json) return MMC_ERROR_CONFIG;

    /* Create new hash object */
    hash_obj = json_object_new_string(new_hash);
    if (!hash_obj) {
        json_object_put(json);
        return MMC_ERROR_CONFIG;
    }

    /* Update hash field */
    json_object_object_del(json, "hash");
    json_object_object_add(json, "hash", hash_obj);

    /* Write updated JSON back to file */
    json_str = json_object_to_json_string_ext(json, JSON_C_TO_STRING_PRETTY);
    if (!json_str) {
        json_object_put(json);
        return MMC_ERROR_CONFIG;
    }

    fp = fopen(config_file, "w");
    if (!fp) {
        json_object_put(json);
        return MMC_ERROR_CONFIG;
    }

    if (fputs(json_str, fp) < 0) {
        fclose(fp);
        json_object_put(json);
        return MMC_ERROR_CONFIG;
    }

    fclose(fp);
    json_object_put(json);
    return MMC_SUCCESS;
} 