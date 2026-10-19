/**
 * @file mmc_common.c
 * @brief Implementation of common utilities for the MMC system
 */

#include <stdarg.h>
#include <time.h>
#include <sys/time.h>
#include <openssl/rand.h>
#include "../include/mmc_common.h"

/**
 * @brief Log a message with timestamp to a file
 *
 * This function:
 * 1. Opens the log file in append mode
 * 2. Gets the current time
 * 3. Formats the timestamp
 * 4. Writes the formatted message with timestamp
 * 5. Closes the file
 *
 * If the log file cannot be opened, the function silently returns.
 *
 * @param log_file Path to the log file
 * @param format Printf-style format string
 * @param ... Variable arguments for the format string
 */
void mmc_log(const char *log_file, const char *format, ...) {
    FILE *fp;
    va_list args;
    time_t now;
    struct tm *tm_info;
    char timestamp[26];

    fp = fopen(log_file, "a");
    if (!fp) return;

    time(&now);
    tm_info = localtime(&now);
    strftime(timestamp, 26, "%Y-%m-%d %H:%M:%S", tm_info);

    fprintf(fp, "[%s] ", timestamp);
    
    va_start(args, format);
    vfprintf(fp, format, args);
    va_end(args);
    
    fprintf(fp, "\n");
    fclose(fp);
}

/**
 * @brief Log an error message with timestamp to a file
 *
 * Similar to mmc_log(), but prefixes the message with "ERROR: "
 * This helps in quickly identifying error messages in the log file.
 *
 * @param log_file Path to the log file
 * @param format Printf-style format string
 * @param ... Variable arguments for the format string
 */
void mmc_log_error(const char *log_file, const char *format, ...) {
    FILE *fp;
    va_list args;
    time_t now;
    struct tm *tm_info;
    char timestamp[26];

    fp = fopen(log_file, "a");
    if (!fp) return;

    time(&now);
    tm_info = localtime(&now);
    strftime(timestamp, 26, "%Y-%m-%d %H:%M:%S", tm_info);

    fprintf(fp, "[%s] ERROR: ", timestamp);
    
    va_start(args, format);
    vfprintf(fp, format, args);
    va_end(args);
    
    fprintf(fp, "\n");
    fclose(fp);
}

/**
 * @brief Generate a random 32-byte hash for authentication
 *
 * Uses OpenSSL's RAND_bytes to generate cryptographically secure random bytes,
 * then converts them to a 64-character hexadecimal string.
 *
 * The generated hash is used in the authentication protocol between
 * MMC components.
 *
 * @return Dynamically allocated string containing the hash, or NULL on failure
 */
char *mmc_generate_hash(void) {
    unsigned char rand_bytes[32];
    char *hash = malloc(MMC_MAX_HASH_SIZE + 1);  /* +1 pour le caractère nul */
    if (!hash) return NULL;

    if (RAND_bytes(rand_bytes, sizeof(rand_bytes)) != 1) {
        free(hash);
        return NULL;
    }

    /* Convertit chaque octet en deux caractères hexadécimaux
     * 32 octets * 2 = 64 caractères
     */
    for (int i = 0; i < 32; i++) {
        sprintf(hash + (i * 2), "%02x", rand_bytes[i]);
    }
    hash[64] = '\0';  /* Termine la chaîne après les 64 caractères */

    return hash;
}

/**
 * @brief Validate a hash string
 *
 * Checks if the provided string is a valid 64-character hexadecimal hash.
 * A valid hash:
 * - Must be exactly 64 characters long
 * - Must only contain hexadecimal characters (0-9, a-f, A-F)
 *
 * @param hash The hash string to validate
 * @return 1 if valid, 0 if invalid
 */
int mmc_validate_hash(const char *hash) {
    if (!hash) return 0;
    
    size_t len = strlen(hash);
    if (len != 64) return 0;

    for (size_t i = 0; i < len; i++) {
        if (!((hash[i] >= '0' && hash[i] <= '9') ||
              (hash[i] >= 'a' && hash[i] <= 'f') ||
              (hash[i] >= 'A' && hash[i] <= 'F'))) {
            return 0;
        }
    }

    return 1;
} 