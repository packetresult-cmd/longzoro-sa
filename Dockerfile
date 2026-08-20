# ==========================================
# 1단계: 빌드 스테이지 (Build Stage)
# ==========================================
FROM ubuntu:20.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# saac 빌드
WORKDIR /app/saac
RUN mkdir build && cd build && cmake .. && make -j$(nproc)

# gmsv 빌드
WORKDIR /app/gmsv
RUN mkdir build && cd build && cmake .. && make -j$(nproc)


# ==========================================
# 2단계: 실행 스테이지 (Runtime Stage)
# ==========================================
FROM ubuntu:20.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# 런타임 필수 패키지 설치
RUN apt-get update && apt-get install -y \
    mysql-client \
    libmysqlclient21 \
    libssl-dev \
    gettext-base \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# SSH 설정
RUN echo 'root:sa@2314' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd

# 포트 개방 (SSH: 22, 게임 서버: 9065)
EXPOSE 22 9065

WORKDIR /app

# 바이너리 및 리소스 복사
COPY --from=builder /app/saac/build/saac /app/saac/
COPY --from=builder /app/saac/char /app/saac/char
COPY --from=builder /app/saac/char_sleep /app/saac/char_sleep
COPY --from=builder /app/saac/data /app/saac/data
COPY --from=builder /app/saac/db /app/saac/db
COPY --from=builder /app/saac/log /app/saac/log
COPY --from=builder /app/saac/mail /app/saac/mail
COPY --from=builder /app/saac/acserv.cf /app/saac/

COPY --from=builder /app/gmsv/build/gmsv /app/gmsv/
COPY --from=builder /app/gmsv/data /app/gmsv/data
COPY --from=builder /app/gmsv/log /app/gmsv/log
COPY --from=builder /app/gmsv/Dengon /app/gmsv/Dengon
COPY --from=builder /app/gmsv/Schedule /app/gmsv/Schedule
COPY --from=builder /app/gmsv/setup.cf /app/gmsv/

# 엔트리포인트 생성 부분 (USERS 테이블 생성 쿼리 추가됨)
RUN echo '#!/bin/bash' > /app/entrypoint.sh && \
    echo '/usr/sbin/sshd' >> /app/entrypoint.sh && \
    echo 'echo "Waiting for MySQL to be ready..."' >> /app/entrypoint.sh && \
    echo 'until mysqladmin ping -h"$DB_HOST" -u"root" -p"$MYSQL_ROOT_PASSWORD" --silent; do sleep 2; done' >> /app/entrypoint.sh && \
    echo 'sleep 3' >> /app/entrypoint.sh && \
    echo 'DB_NAME=$(grep "SQL_DBNAME" /app/saac/acserv.cf | head -n 1 | cut -d"=" -f2 | tr -d " \r\t")' >> /app/entrypoint.sh && \
    echo 'DB_USER=$(grep "SQL_USER" /app/saac/acserv.cf | head -n 1 | cut -d"=" -f2 | tr -d " \r\t")' >> /app/entrypoint.sh && \
    echo 'DB_PASS=$(grep "SQL_PASS" /app/saac/acserv.cf | head -n 1 | cut -d"=" -f2 | tr -d " \r\t")' >> /app/entrypoint.sh && \
    echo '[ -z "$DB_NAME" ] && DB_NAME="sa"' >> /app/entrypoint.sh && \
    echo '[ -z "$DB_USER" ] && DB_USER="sa"' >> /app/entrypoint.sh && \
    echo '[ -z "$DB_PASS" ] && DB_PASS="123456"' >> /app/entrypoint.sh && \
    echo 'echo "Parsed DB_NAME: [$DB_NAME], DB_USER: [$DB_USER]"' >> /app/entrypoint.sh && \
    echo '# MySQL 계정, DB 및 USERS 테이블 생성' >> /app/entrypoint.sh && \
    echo 'mysql -h"$DB_HOST" -u"root" -p"$MYSQL_ROOT_PASSWORD" <<EOF &&' >> /app/entrypoint.sh && \
    echo "CREATE DATABASE IF NOT EXISTS \${DB_NAME};" >> /app/entrypoint.sh && \
    echo "CREATE USER IF NOT EXISTS '\${DB_USER}'@'%' IDENTIFIED BY '\${DB_PASS}';" >> /app/entrypoint.sh && \
    echo "CREATE USER IF NOT EXISTS '\${DB_USER}'@'localhost' IDENTIFIED BY '\${DB_PASS}';" >> /app/entrypoint.sh && \
    echo "ALTER USER '\${DB_USER}'@'%' IDENTIFIED BY '\${DB_PASS}';" >> /app/entrypoint.sh && \
    echo "ALTER USER '\${DB_USER}'@'localhost' IDENTIFIED BY '\${DB_PASS}';" >> /app/entrypoint.sh && \
    echo "GRANT ALL PRIVILEGES ON \${DB_NAME}.* TO '\${DB_USER}'@'%';" >> /app/entrypoint.sh && \
    echo "GRANT ALL PRIVILEGES ON \${DB_NAME}.* TO '\${DB_USER}'@'localhost';" >> /app/entrypoint.sh && \
    echo "FLUSH PRIVILEGES;" >> /app/entrypoint.sh && \
    echo "USE \${DB_NAME};" >> /app/entrypoint.sh && \
    echo "CREATE TABLE IF NOT EXISTS USERS (" >> /app/entrypoint.sh && \
    echo "  USERNAME varchar(16) character set utf8 collate utf8_bin NOT NULL," >> /app/entrypoint.sh && \
    echo "  PASSWORD varchar(16) character set utf8 collate utf8_bin NOT NULL," >> /app/entrypoint.sh && \
    echo "  REGISTER datetime NOT NULL default CURRENT_TIMESTAMP," >> /app/entrypoint.sh && \
    echo "  PATH varchar(10) default ''," >> /app/entrypoint.sh && \
    echo "  PRIMARY KEY (USERNAME)" >> /app/entrypoint.sh && \
    echo ");" >> /app/entrypoint.sh && \
    echo 'EOF' >> /app/entrypoint.sh && \
    echo 'echo "Database, User and USERS table setup finished successfully."' >> /app/entrypoint.sh && \
    echo 'mkdir -p /app/saac/log /app/gmsv/log' >> /app/entrypoint.sh && \
    echo 'cd /app/saac && ./saac > /app/saac/log/saac.log 2>&1 &' >> /app/entrypoint.sh && \
    echo 'cd /app/gmsv && ./gmsv > /app/gmsv/log/gmsv.log 2>&1 &' >> /app/entrypoint.sh && \
    echo 'wait || { echo "Server failed to start"; exit 1; }' >> /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]