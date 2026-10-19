#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netdb.h>

#define SERVER_PORT 9000
#define BUF_SIZE 1024

int main(int argc, char *argv[]){
    if(argc < 3){
        printf("Usage: %s <server_ipv6> <message>\n", argv[0]);
        return 1;
    }

    const char *server_ip = argv[1];
    const char *message   = argv[2];

    int sock = socket(AF_INET6, SOCK_STREAM, 0);
    if(sock < 0){
        perror("socket");
        return 1;
    }

    struct sockaddr_in6 server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin6_family = AF_INET6;
    inet_pton(AF_INET6, server_ip, &server_addr.sin6_addr);
    server_addr.sin6_port = htons(SERVER_PORT);

    if(connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0){
        perror("connect");
        return 1;
    }

    send(sock, message, strlen(message), 0);
    printf("[Client] Sent: %s\n", message);

    close(sock);
    return 0;
}
