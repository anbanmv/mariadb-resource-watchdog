# mariadb-resource-watchdog
A lightweight shell utility to observe MariaDB resource usage (CPU, memory, and connections) at a fixed interval.
**Note:** _This is designed for incident analysis and short-term diagnostics, not continuous monitoring._

# What problem does this solve?
When a MariaDB node is under stress you often need quick answers:
- Is MariaDB actually consuming CPU or memory right now?
- Are connection counts climbing during the incident?
- Is RSS growing while the buffer pool stays stable?
- Do resource spikes correlate with application issues?
This script provides a low overhead, zero dependency way to capture MariaDB resource behavior over time without setting up Prometheus, exporters, or agents.

# Typical use cases:
- During production incidents
- While reproducing performance issues
- Short-term validation after config changes
- Correlating DB behavior with system metrics

# Sample output:
```
TIME       CPU%   MEM%   VM(MB)     RSS(MB)    CONNS
----------------------------------------------------
10:01:00   132.4  18.7   24576.3    8123.6     184
10:02:00   128.9  18.9   24576.3    8192.4     192
10:03:00   140.1  19.2   24576.3    8345.1     201
```
Each line represents a single sampling interval and can be easily correlated with:
- application logs
- slow query logs
- system metrics (vmstat, iostat, sar)
Logs are written to a timestamped file for later review.

# How to configure authentication:
The script does not accept credentials via arguments or environment variables. It relies on standard MySQL client authentication using a config file.
Recommended approach: `~/.my.cnf`
Create a dedicated read only MariaDB user and store credentials locally:
```
[client]
user=watchdog_user
password=STRONG_PASSWORD
host=localhost
```

# Set proper permissions:
```
chmod 600 ~/.my.cnf
```

# Minimal required privileges:
```
CREATE USER 'watchdog_user'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD';
GRANT PROCESS, SHOW DATABASES ON *.* TO 'watchdog_user'@'localhost';
FLUSH PRIVILEGES;
```
