/**
 * @file mmc_common.h
 * @brief Common definitions and utilities for the MMC (Message to Machine Communication) system
 *
 * This header file provides common functionality used across all MMC components:
 * - Message size and buffer limitations
 * - Protocol message definitions
 * - Error codes
 * - Logging functions
 * - Hash generation and validation for authentication
 */

#ifndef MMC_COMMON_H
#define MMC_COMMON_H

/* Standard includes for basic functionalities */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

/**
 * @brief Maximum buffer sizes used throughout the MMC system
 */
#define MMC_MAX_MSG_SIZE 1024    /**< Maximum size for any message payload */
#define MMC_MAX_HASH_SIZE 65     /**< Size for authentication hashes (64 hex chars + null terminator) */
#define MMC_MAX_PATH_SIZE 256    /**< Maximum path length for files and network addresses */

/**
 * @brief Protocol message prefixes used in the MMC communication protocol
 *
 * The protocol follows this sequence:
 * 1. Host daemon sends "hello-<hash>" to initiate authentication
 * 2. Client responds with "welcome-<hash>" to complete authentication
 * 3. Messages are sent with "SEND " prefix
 * 4. Client sends "END" to terminate the connection
 */
#define MMC_MSG_HELLO "hello-"     /**< Authentication initiation message */
#define MMC_MSG_WELCOME "welcome-"  /**< Authentication response message */
#define MMC_MSG_SEND "SEND "       /**< Prefix for actual message payload */
#define MMC_MSG_END "END"          /**< Connection termination message */
#define MMC_MSG_RESPONSE "RESP "   /**< Prefix for response messages */
#define MMC_MSG_SPECIAL "SPEC "    /**< Prefix for special commands executed locally by VM daemon */

/**
 * @brief Error codes returned by MMC functions
 */
typedef enum {
    MMC_SUCCESS = 0,              /**< Operation completed successfully */
    MMC_ERROR_CONFIG = -1,        /**< Configuration error (file not found, invalid format, etc.) */
    MMC_ERROR_NETWORK = -2,       /**< Network error (connection failed, socket error, etc.) */
    MMC_ERROR_SYSTEM = -3         /**< System error (memory allocation, file operations, etc.) */
} mmc_error_t;

/**
 * @brief Log a normal message with timestamp to the specified log file
 *
 * @param log_file Path to the log file
 * @param format Printf-style format string
 * @param ... Variable arguments for the format string
 */
void mmc_log(const char *log_file, const char *format, ...);

/**
 * @brief Log an error message with timestamp to the specified log file
 *
 * @param log_file Path to the log file
 * @param format Printf-style format string
 * @param ... Variable arguments for the format string
 */
void mmc_log_error(const char *log_file, const char *format, ...);

/**
 * @brief Generate a random 32-byte hash for authentication
 *
 * Uses OpenSSL's RAND_bytes to generate a cryptographically secure random hash.
 * The hash is returned as a 64-character hexadecimal string.
 *
 * @return Dynamically allocated string containing the hash, or NULL on failure
 */
char *mmc_generate_hash(void);

/**
 * @brief Validate a hash string
 *
 * Checks if the provided string is a valid 64-character hexadecimal hash.
 *
 * @param hash The hash string to validate
 * @return 1 if valid, 0 if invalid
 */
int mmc_validate_hash(const char *hash);

#endif /* MMC_COMMON_H */ 