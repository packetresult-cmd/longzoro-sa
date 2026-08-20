# 1. 기존 컨테이너 및 꼬인 DB 볼륨 완전 삭제 (-v 필수)
docker-compose down -v

# 2. 새로 빌드 후 백그라운드 실행
docker-compose up --build -d