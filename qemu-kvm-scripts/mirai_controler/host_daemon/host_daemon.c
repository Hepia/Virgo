#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <stdarg.h>

#define SERVER_PORT 9000
#define UNIX_SOCKET_PATH "/tmp/vm_virtio.sock"
#define BUF_SIZE 1024

void log_with_time(const char *format, ...){
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);

    char time_buf[26];
    strftime(time_buf, sizeof(time_buf), "%Y-%m-%d %H:%M:%S", tm_info);

    printf("[%s] ", time_buf);

    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);

    printf("\n");
}

int main(){
    int tcp_sock, new_sock;
    struct sockaddr_in6 server_addr;
    char buffer[BUF_SIZE];

    tcp_sock = socket(AF_INET6, SOCK_STREAM, 0);
    if(tcp_sock < 0){
        perror("socket");
        exit(EXIT_FAILURE);
    }

    int opt = 1;
    setsockopt(tcp_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin6_family = AF_INET6;
    server_addr.sin6_addr   = in6addr_any;
    server_addr.sin6_port   = htons(SERVER_PORT);

    if(bind(tcp_sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0){
        perror("bind");
        exit(EXIT_FAILURE);
    }

    listen(tcp_sock, 5);

    log_with_time("[Host Daemon] Listening on port %d", SERVER_PORT);

    while(1){
        new_sock = accept(tcp_sock, NULL, NULL);
        if(new_sock < 0){
            perror("accept");
            continue;
        }

        ssize_t bytes = read(new_sock, buffer, sizeof(buffer) - 1);
        if (bytes > 0){
            buffer[bytes] = '\0';
            log_with_time("[Host Daemon] Received from client: %s", buffer);

            // Connect ot UNIX socket
            int unix_sock = socket(AF_UNIX, SOCK_STREAM, 0);
            if(unix_sock < 0){
                perror("socket AF_UNIX");
                continue;
            }

            struct sockaddr_un addr;
            memset(&addr, 0, sizeof(addr));
            addr.sun_family = AF_UNIX;
            strncpy(addr.sun_path, UNIX_SOCKET_PATH, sizeof(addr.sun_path) - 1);

            if(connect(unix_sock, (struct sockaddr*)&addr, sizeof(addr)) < 0){
                perror("connect UNIX");
                close(unix_sock);
                continue;
            }

            write(unix_sock, buffer, strlen(buffer));
            close(unix_sock);
        }

        close(new_sock);
    }

    close(tcp_sock);
    return 0;
}
