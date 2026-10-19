#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <stdarg.h>

#define DEVICE_PATH "/dev/virtio-ports/com.myvm.channel"
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
    int fd = open(DEVICE_PATH, O_RDONLY);
    if(fd < 0){
        perror("Failed to open virtio port");
        return 1;
    }

    char buf[BUF_SIZE];

    while(1){
        ssize_t n = read(fd, buf, sizeof(buf) - 1);
        if(n > 0){
            buf[n] = '\0';
            log_with_time("[VM Daemon] %s", buf);
        }else if (n == 0){
            sleep(1);
        }else{
            perror("read");
            break;
        }
    }

    close(fd);

    return 0;
}
