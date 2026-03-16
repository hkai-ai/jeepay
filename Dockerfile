#
#   Jeepay 统一构建镜像 - 支持通过 PLATFORM 参数构建 manager/merchant/payment
#   用法: docker build --build-arg PLATFORM=manager --build-arg PORT=9217 -t jeepay-manager .
#

# ====== 第一阶段: Maven 编译 ======
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /build

# 先复制 pom.xml 利用 Docker 缓存加速依赖下载
COPY pom.xml .
COPY jeepay-core/pom.xml jeepay-core/pom.xml
COPY jeepay-service/pom.xml jeepay-service/pom.xml
COPY jeepay-manager/pom.xml jeepay-manager/pom.xml
COPY jeepay-merchant/pom.xml jeepay-merchant/pom.xml
COPY jeepay-payment/pom.xml jeepay-payment/pom.xml
COPY jeepay-components/pom.xml jeepay-components/pom.xml
COPY jeepay-components/jeepay-components-oss/pom.xml jeepay-components/jeepay-components-oss/pom.xml
COPY jeepay-components/jeepay-components-mq/pom.xml jeepay-components/jeepay-components-mq/pom.xml
COPY jeepay-z-codegen/pom.xml jeepay-z-codegen/pom.xml

# 下载依赖（利用缓存层，源码不变时不会重新下载）
RUN mvn dependency:go-offline -B -pl !jeepay-z-codegen || true

# 复制全部源码并编译
COPY . .
RUN mvn package -B -DskipTests -pl !jeepay-z-codegen

# ====== 第二阶段: 运行时镜像 ======
FROM eclipse-temurin:17-jre

# 构建参数
ARG PLATFORM=manager
ARG PORT=9217

ENV LANG=C.UTF-8
ENV TZ=Asia/Shanghai
ENV JVM_OPTS=""

EXPOSE ${PORT}

VOLUME ["/workspace/logs", "/workspace/uploads"]

WORKDIR /workspace

# 从编译阶段复制对应平台的 JAR
COPY --from=builder /build/jeepay-${PLATFORM}/target/jeepay-${PLATFORM}.jar app.jar

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:${PORT}/ || exit 1

ENTRYPOINT ["sh", "-c", "java $JVM_OPTS -jar app.jar"]
