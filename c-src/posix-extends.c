#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/time.h>
#include "posix-extends.h"

struct timeval timeout;

int keepinterval(int sockfd) {
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;
  return setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPINTVL, &timeout, sizeof timeout);
}

int tcp_keepalive(int sockfd) {
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;
  #ifdef __APPLE__
  return setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPALIVE, &timeout, sizeof timeout);
  #else __unix__
  return setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPIDLE, &timeout, sizeof timeout);
  #endif
}

int tcp_keepcnt(int sockfd) {
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;
  return setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPCNT, &timeout, sizeof timeout);
}

int so_rectimeo2zero(int sockfd) {
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;
  return setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof timeout);
}

int so_sndtimeo2zero(int sockfd) {
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;
  return setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof timeout);
}
