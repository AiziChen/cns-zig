#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/time.h>
#include "posix-extends.h"

struct timeval timeout;

int keepinterval(int sockfd) {
  return setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPINTVL, 0, 0);
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
