git init
git add .
read -p "커밋 메시지를 입력하세요: " msg
git commit -m "$msg"
git branch -M main
git remote add origin https://github.com/packetresult-cmd/longzoro-sa.git
git push -u origin main