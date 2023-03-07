FROM alpine:3.17
RUN apk update && \
    apk add font-noto perl-archive-zip perl-html-parser perl-rrd php-apache2 && \
    mkdir -p /var/www/localhost/htdocs/dstat2graphs/reports && \
    chown apache:apache /var/www/localhost/htdocs/dstat2graphs/reports
COPY php_dstat.ini /etc/php81/conf.d/
COPY src/ /var/www/localhost/htdocs/dstat2graphs/
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]
