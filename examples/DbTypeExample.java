package examples;

/**
 * 多数据库 JDBC 连接串拼接的通用写法示例。
 *
 * <p>以三种代表性数据库为例，说明连接串格式差异、以及各自常见的连接参数坑，
 * 集中在一个地方处理，业务代码只传 host/port/database。
 *
 * <p>这是一个业界通用的 JDBC 知识整理，不涉及任何业务逻辑。
 */
public enum DbTypeExample {

    MYSQL("MySQL", 3306, "com.mysql.cj.jdbc.Driver"),
    SQLSERVER("SQL Server", 1433, "com.microsoft.sqlserver.jdbc.SQLServerDriver"),
    POSTGRESQL("PostgreSQL", 5432, "org.postgresql.Driver");

    private final String label;
    private final int defaultPort;
    private final String driverClass;

    DbTypeExample(String label, int defaultPort, String driverClass) {
        this.label = label;
        this.defaultPort = defaultPort;
        this.driverClass = driverClass;
    }

    public String getLabel() {
        return label;
    }

    public int getDefaultPort() {
        return defaultPort;
    }

    public String getDriverClass() {
        return driverClass;
    }

    /**
     * 按数据库类型拼出 JDBC URL。
     *
     * <p>各类型的常见坑：
     * <ul>
     *   <li>MySQL 8 默认要求 SSL，内网库一般没配 → useSSL=false；</li>
     *   <li>MySQL caching_sha2 认证需要 allowPublicKeyRetrieval=true；</li>
     *   <li>SQL Server 新版驱动默认 encrypt=true，老库没证书 → encrypt=false；</li>
     *   <li>连接超时统一设短一些，避免页面长时间卡住。</li>
     * </ul>
     */
    public String buildUrl(String host, int port, String database) {
        switch (this) {
            case MYSQL:
                return "jdbc:mysql://" + host + ":" + port + "/" + database
                        + "?useSSL=false&allowPublicKeyRetrieval=true"
                        + "&useUnicode=true&characterEncoding=utf8"
                        + "&serverTimezone=Asia/Shanghai"
                        + "&connectTimeout=5000&socketTimeout=60000";
            case SQLSERVER:
                return "jdbc:sqlserver://" + host + ":" + port
                        + ";databaseName=" + database
                        + ";encrypt=false;loginTimeout=5";
            case POSTGRESQL:
                return "jdbc:postgresql://" + host + ":" + port + "/" + database
                        + "?connectTimeout=5&socketTimeout=60";
            default:
                throw new IllegalStateException("unsupported db type: " + this);
        }
    }
}
