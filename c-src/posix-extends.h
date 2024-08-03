
extern int keepinterval(int sockfd);
extern int tcp_keepalive(int sockfd);
int tcp_keepcnt(int sockfd);

extern int so_rectimeo2zero(int sockfd);
extern int so_sndtimeo2zero(int sockfd);
