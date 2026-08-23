# Cisco 2600XM Terminal Server Configuration
## Setup Script and Documentation

**Prepared By:** Thomas Van Auken — Van Auken Tech  
**Device:** Cisco 2610XM (IOS 12.2(8)T5, IP Base)  
**Management IP:** 172.21.10.254/24  

---

## Quick Reference

### Connect via Reverse Telnet
```bash
# Through existing terminal server on port 2038
telnet 192.168.200.254 2038
# Send 2x Enter to wake console
```

### Direct Access
```bash
# Admin access
telnet 172.21.10.254
Username: admin
Password: Wiicco@111!!

# Viewer access (menu only)
Username: viewer
Password: QXz69
```

### Verify Configuration
```bash
show running-config
show version
show ip interface brief
show line
```

## Key Differences from Original Terminal Server

| Parameter | rt-cisco-01 | RT-TERMINAL-01 |
|-----------|-------------|-----------------|
| IP Address | 192.168.200.254 | 172.21.10.254 |
| Gateway | 192.168.200.1 | 172.21.10.1 |
| Serial Speed | 115200 | 9600 |
| Admin Password | VanAwsome1 | Wiicco@111!! |

## Documentation

- [Full User Guide](../RT-TERMINAL-01/docs/user-manual.md)
- [Complete Build Log](../RT-TERMINAL-01/docs/build-log.md)

---

**Thomas Van Auken — Van Auken Tech**
