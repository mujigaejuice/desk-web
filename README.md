# call-desk

전화 응대 매니저웹. Spring Boot 4.1(Java 25) + React 19(Vite 8) + PostgreSQL 18.

- [개발 계획](docs/dev-plan.md)
- [환경 설정](docs/environment-setup.md)
- [배포 체크리스트](docs/deploy-checklist.md)

## 로컬 실행

```bash
docker compose up -d          # PostgreSQL(5433), Mailpit(SMTP 1025, 웹 8025)

cd backend && ./gradlew bootRun   # Windows: gradlew.bat bootRun  → http://localhost:8080
cd frontend && npm run dev        # → http://localhost:5173 (/api, /ws는 8080으로 프록시)
```

로컬 DB 포트는 5433입니다. 환경 설정 문서의 5432에서 바꿨습니다(같은 PC의 다른 프로젝트가 5432를 사용 중).

## jar 하나로 빌드

```bash
cd backend
./gradlew bootJar -PwithFrontend
java -jar build/libs/calldesk-0.0.1-SNAPSHOT.jar
```
