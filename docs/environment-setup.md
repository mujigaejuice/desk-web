# 전화 응대 매니저웹 환경 설정

2026-11-17 기준

이 문서를 위에서부터 따라 하면 `call-desk/` 저장소에 백엔드, 프런트엔드, 로컬 DB가 갖춰지고 개발 서버 두 개가 뜹니다. 명령은 macOS와 Linux 셸 기준이며, Windows는 Git Bash나 WSL에서 그대로 쓰거나 표시한 차이를 따릅니다.

관련 문서: [개발 계획](dev-plan.md), [배포 체크리스트](deploy-checklist.md)

> **검증 범위**
> 프런트엔드 쪽(Vite 프로젝트 생성, 프록시 설정, 빌드)은 실제로 실행해 확인했습니다. 백엔드 쪽(Spring Initializr, Gradle 설정, `application.yml`, `compose.yaml`)은 실행해 보지 못했으므로, 처음 실행에서 오류가 나면 그 부분부터 확인하세요.

## 1. 준비물

| 도구 | 버전 | 확인 명령 | 비고 |
| --- | --- | --- | --- |
| JDK | 25(LTS) | `java -version` | Spring Boot 4.1은 Java 17 이상에서 동작 |
| Node.js | 24 LTS 이상 | `node -v` | Vite 8은 20.19 이상 또는 22.12 이상 필요 |
| Docker | Compose 포함 | `docker compose version` | 로컬 PostgreSQL과 테스트 메일 서버용 |
| Git | 최신 | `git --version` | |

Gradle은 따로 설치하지 않습니다. 프로젝트에 포함되는 wrapper(`gradlew`)를 씁니다.

이 문서가 기준으로 삼은 버전은 다음과 같습니다.

| 구성 요소 | 버전 | 비고 |
| --- | --- | --- |
| Spring Boot | 4.1.x | 4.2는 정식 출시 후에 올림 |
| PostgreSQL | 18 | Docker 이미지 `postgres:18` |
| Vite | 8 | `react-ts` 템플릿 |
| React | 19 | 템플릿 기본값 |
| TypeScript | 7 | 템플릿 기본값 |
| @stomp/stompjs | 7 | 웹소켓 STOMP 클라이언트 |

## 2. 만들 디렉토리 구조

```text
call-desk/
├── README.md
├── compose.yaml                  로컬 PostgreSQL, 테스트 메일 서버
├── .gitignore
├── docs/
│   ├── deploy-checklist.md
│   ├── dev-plan.md
│   └── environment-setup.md
├── backend/                      Spring Boot (Gradle)
│   ├── build.gradle
│   ├── settings.gradle
│   ├── gradlew, gradlew.bat, gradle/
│   └── src/
│       ├── main/
│       │   ├── java/com/example/calldesk/
│       │   │   ├── CalldeskApplication.java
│       │   │   ├── config/       보안, 웹소켓, 스케줄러 설정
│       │   │   ├── auth/         로그인, 권한
│       │   │   ├── member/       직원
│       │   │   ├── seat/         파티션, 상태, 자동 복귀
│       │   │   ├── task/         업무, 키워드
│       │   │   ├── search/       검색, 검색 로그
│       │   │   ├── note/         파티션 메모
│       │   │   ├── callmemo/     전화 메모
│       │   │   ├── mail/         발송 대기열, 재시도
│       │   │   ├── importer/     AI 구조화, 가져오기
│       │   │   └── common/       공통 예외, 응답
│       │   └── resources/
│       │       ├── application.yml
│       │       ├── application-dev.yml
│       │       ├── application-prod.yml
│       │       └── db/migration/V1__init.sql
│       └── test/java/com/example/calldesk/
└── frontend/                     React (Vite)
    ├── package.json
    ├── vite.config.ts
    ├── index.html
    └── src/
        ├── main.tsx
        ├── App.tsx
        ├── api/                  REST 호출
        ├── ws/                   STOMP 연결과 구독
        ├── pages/                전화 응대, 내 자리, 관리자
        ├── components/           배치도, 신호등, 메모
        ├── hooks/
        └── types/
```

`com.example`은 예시입니다. 소속에 맞는 패키지 이름으로 바꾸세요.

## 3. 저장소 만들기

```bash
mkdir call-desk && cd call-desk
git init
mkdir docs
```

`docs/`에 문서 세 개(`deploy-checklist.md`, `dev-plan.md`, `environment-setup.md`)를 넣습니다.

루트에 `.gitignore`를 만듭니다. `backend/`와 `frontend/`에는 생성 도구가 각자의 `.gitignore`를 만들어 줍니다.

```gitignore
.env
*.log
.DS_Store
.idea/
.vscode/
```

## 4. 로컬 DB와 테스트 메일 서버

루트에 `compose.yaml`을 만듭니다. Mailpit은 보낸 메일을 실제로 내보내지 않고 웹 화면에 보여 주는 테스트용 메일 서버입니다.

```yaml
services:
  db:
    image: postgres:18
    environment:
      POSTGRES_DB: calldesk
      POSTGRES_USER: calldesk
      POSTGRES_PASSWORD: calldesk
      TZ: Asia/Seoul
    ports:
      - "5432:5432"
    volumes:
      - calldesk-db:/var/lib/postgresql

  mail:
    image: axllent/mailpit
    ports:
      - "1025:1025"
      - "8025:8025"

volumes:
  calldesk-db:
```

```bash
docker compose up -d
docker compose ps
```

- PostgreSQL 18 이미지부터 볼륨 경로가 `/var/lib/postgresql`입니다. 17 이하 이미지를 쓴다면 `/var/lib/postgresql/data`로 바꿉니다.
- 이미 5432 포트를 쓰는 PostgreSQL이 있으면 왼쪽 포트를 바꾸고(`"5433:5432"`), 5번의 접속 주소도 같이 바꿉니다.
- 여기 적은 비밀번호는 로컬 개발 전용입니다.

## 5. 백엔드 만들기

### 5.1 프로젝트 생성

[start.spring.io](https://start.spring.io)에서 아래처럼 고르고 내려받은 압축 파일을 `call-desk/backend/`에 풉니다.

| 항목 | 값 |
| --- | --- |
| Project | Gradle - Groovy |
| Language | Java |
| Spring Boot | 4.1.x 중 SNAPSHOT, M, RC가 붙지 않은 것 |
| Group | `com.example` |
| Artifact, Name | `calldesk` |
| Packaging | Jar |
| Java | 25 |
| Dependencies | Spring Web, WebSocket, Spring Security, Spring Data JPA, Flyway Migration, PostgreSQL Driver, Java Mail Sender, Validation, Spring Boot Actuator |

명령으로 받으려면 저장소 루트에서 아래를 실행합니다. Spring Boot 버전을 지정하지 않았으므로 그 시점의 기본 정식 버전으로 생성됩니다.

```bash
curl -sS https://start.spring.io/starter.zip \
  -d type=gradle-project -d language=java -d javaVersion=25 \
  -d groupId=com.example -d artifactId=calldesk -d name=calldesk \
  -d packageName=com.example.calldesk \
  -d dependencies=web,websocket,security,data-jpa,flyway,postgresql,mail,validation,actuator \
  -d baseDir=backend -o backend.zip
unzip backend.zip && rm backend.zip
```

Spring Boot 4부터 스타터 이름이 바뀌었습니다(예: 웹은 `spring-boot-starter-webmvc`, Flyway는 `spring-boot-starter-flyway`). 예전 글의 의존성 목록을 옮겨 적지 말고 Initializr가 만든 `build.gradle`을 기준으로 삼으세요.

### 5.2 패키지와 리소스 디렉토리

저장소 루트에서 실행합니다.

```bash
PKG=backend/src/main/java/com/example/calldesk
mkdir -p $PKG/{config,auth,member,seat,task,search,note,callmemo,mail,importer,common}
mkdir -p backend/src/main/resources/db/migration
```

PowerShell에서는 중괄호 확장이 되지 않으므로 디렉토리를 하나씩 만듭니다.

### 5.3 설정 파일

`backend/src/main/resources/`에 `application.properties`가 생성돼 있으면 지우고 아래 세 파일을 만듭니다.

`application.yml` (공통)

```yaml
spring:
  application:
    name: calldesk
  profiles:
    default: dev
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: validate

server:
  port: 8080
  servlet:
    session:
      timeout: 8h

app:
  mail-from: ${MAIL_FROM:calldesk@localhost}
  llm-api-key: ${LLM_API_KEY:}
```

`application-dev.yml` (로컬 개발)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/calldesk
    username: calldesk
    password: calldesk
  mail:
    host: localhost
    port: 1025
```

`application-prod.yml` (운영, 값은 모두 환경변수에서)

```yaml
spring:
  datasource:
    url: ${DB_URL}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  mail:
    host: ${MAIL_HOST}
    port: ${MAIL_PORT:25}
    username: ${MAIL_USERNAME:}
    password: ${MAIL_PASSWORD:}
```

`app.*`는 애플리케이션 코드에서 읽을 값이고 이름은 예시입니다.

### 5.4 첫 마이그레이션

`backend/src/main/resources/db/migration/V1__init.sql`을 만듭니다. Flyway가 동작하는지 확인하는 용도로 `member` 테이블만 먼저 넣고, 나머지 테이블은 개발 계획의 데이터 모델에 따라 `V2`부터 추가합니다.

```sql
create table member (
    id         bigint generated always as identity primary key,
    name       varchar(50)  not null,
    login_id   varchar(50)  not null unique,
    password   varchar(100) not null,
    role       varchar(20)  not null,
    extension  varchar(20),
    created_at timestamptz  not null default now()
);
```

### 5.5 시간대 고정

자리비움 종료 시각과 자동 복귀가 서버 시간대에 좌우되므로 `CalldeskApplication.java`의 `main` 첫 줄에서 고정합니다.

```java
public static void main(String[] args) {
    TimeZone.setDefault(TimeZone.getTimeZone("Asia/Seoul"));
    SpringApplication.run(CalldeskApplication.class, args);
}
```

## 6. 프런트엔드 만들기

저장소 루트에서 실행합니다.

```bash
npm create vite@latest frontend -- --template react-ts
cd frontend
npm install
npm install @stomp/stompjs
mkdir -p src/{api,ws,pages,components,hooks,types}
cd ..
```

`frontend/vite.config.ts`를 아래로 바꿉니다. 개발 중에는 화면(5173 포트)이 `/api`와 웹소켓 `/ws` 요청을 백엔드(8080 포트)로 넘기므로 CORS 설정이 필요 없고, 운영에서 jar 하나로 합쳤을 때와 주소 체계가 같아집니다.

```ts
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8080',
      '/ws': { target: 'http://localhost:8080', ws: true },
    },
  },
})
```

## 7. 실행 확인

터미널 두 개를 엽니다.

```bash
# 터미널 1: 백엔드
cd backend
./gradlew bootRun        # Windows: gradlew.bat bootRun

# 터미널 2: 프런트엔드
cd frontend
npm run dev
```

- [ ] `docker compose ps`에 `db`와 `mail`이 실행 중으로 보인다
- [ ] 백엔드 로그에 Flyway가 마이그레이션 1개를 적용했다고 나온다
- [ ] `http://localhost:8080`에 접속하면 Spring Security 기본 로그인 화면이 뜬다
- [ ] `http://localhost:5173`에 Vite 기본 화면이 뜬다
- [ ] `http://localhost:8025`에 Mailpit 화면이 뜬다

여기까지 되면 첫 커밋을 합니다.

```bash
git add .
git commit -m "프로젝트 뼈대"
```

## 8. jar 하나로 빌드

`backend/build.gradle` 맨 아래에 추가합니다. `-PwithFrontend`를 붙였을 때만 React를 빌드해 jar의 `static/`에 넣으므로, 평소 `bootRun`은 느려지지 않습니다.

```groovy
// React 빌드 결과를 jar에 포함: ./gradlew bootJar -PwithFrontend
if (project.hasProperty('withFrontend')) {
    def frontendDir = file('../frontend')
    def npm = System.getProperty('os.name').toLowerCase().contains('windows') ? 'npm.cmd' : 'npm'

    tasks.register('npmCi', Exec) {
        workingDir frontendDir
        commandLine npm, 'ci'
    }

    tasks.register('buildFrontend', Exec) {
        dependsOn 'npmCi'
        workingDir frontendDir
        commandLine npm, 'run', 'build'
    }

    tasks.named('processResources') {
        dependsOn 'buildFrontend'
        from("$frontendDir/dist") {
            into 'static'
        }
    }
}
```

```bash
cd backend
./gradlew bootJar -PwithFrontend
java -jar build/libs/calldesk-0.0.1-SNAPSHOT.jar
```

jar로 띄운 뒤 화면이 보이려면 보안 설정에서 `/`, `/index.html`, `/assets/**`를 로그인 없이 열어 줘야 합니다. 이 설정과 로그인 화면은 개발 계획 1~2주차 작업에서 만듭니다.

## 9. 운영 환경변수

운영 서버에서는 아래 값을 환경변수로 넣고 실행합니다. 값은 저장소에 올리지 않습니다.

| 변수 | 용도 |
| --- | --- |
| `SPRING_PROFILES_ACTIVE` | `prod`로 지정 |
| `DB_URL` | 예: `jdbc:postgresql://호스트:5432/calldesk` |
| `DB_USERNAME`, `DB_PASSWORD` | DB 계정 |
| `MAIL_HOST`, `MAIL_PORT` | 사내 메일 서버 주소와 포트 |
| `MAIL_USERNAME`, `MAIL_PASSWORD` | 메일 서버가 인증을 요구할 때만 |
| `MAIL_FROM` | 알림 메일 발신 주소 |
| `LLM_API_KEY` | AI 구조화를 서버에서 돌릴 때만 |

```bash
SPRING_PROFILES_ACTIVE=prod java -jar calldesk-0.0.1-SNAPSHOT.jar
```
