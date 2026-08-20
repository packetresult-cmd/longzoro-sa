# Project Repository

이 프로젝트는 Docker 기반의 서비스 환경을 구축하고 관리하기 위한 설정을 포함하고 있습니다.

## 작성자
PacketResult

## 포함된 파일 및 설명

- **`.gitignore`**: Git 관리에서 제외할 파일이나 디렉토리 목록을 정의합니다.
- **`docker-compose.yml`**: Docker 컨테이너 오케스트레이션을 위한 설정 파일입니다. 서비스 환경을 쉽게 구축하고 실행할 수 있습니다.
- **`Dockerfile`**: Docker 이미지 빌드를 위한 설정 파일입니다. 애플리케이션의 실행 환경을 정의합니다.
- **`docker-reset.bat`**: Windows 환경에서 Docker 컨테이너 및 볼륨 등을 초기화하기 위한 배치 파일입니다.
- **`gitupload.sh`**: Git 저장소에 변경 사항을 업로드하기 위한 쉘 스크립트입니다.
- **`ReadMe.md`**: 현재 이 프로젝트에 대한 설명 문서입니다.

## 사용 방법

1. **Docker 환경 실행**:
   ```bash
   docker-compose up -d