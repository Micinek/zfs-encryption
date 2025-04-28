# **ZFS Dataset encryption and unlocking methods**  

1️⃣ **Simplest (Local File-Based Key Storage)**  
2️⃣ **SSH-Based Unlock (Remote Key Server via SSH)**  
3️⃣ **TLS Client Certificate Authentication (Secure HTTPS Key Fetch)**  

---

# **🔥 Full Comparison: Local File vs. SSH vs. TLS Client Certs**  

| Feature | **Local File-Based Key** (Simplest) | **SSH-Based Unlock** | **TLS Client Certificate Unlock** |
|---------|---------------------------------|----------------------|--------------------------------|
| **How It Works** | Stores **key in a local file** (`file://...`) | Fetches **key via SSH** to a remote server | Fetches **key over HTTPS** from an Nginx key server |
| **Key Storage Location** | Locally (`/etc/zfs/keys/`) | Remotely (via SSH) | Remotely (via HTTPS) |
| **Authentication Method** | None (Relies on file permissions) | SSH keys | TLS client certificates |
| **Encryption** | File **must be protected manually** (`chmod 600`) | SSH encrypts key transfer | TLS encrypts key transfer |
| **Security Level** | ⚠️ **Least secure** ❌ | 🔹 **Very secure** ✅ | 🔹 **Very secure** ✅ |
| **Automated Dataset unlock?** | ✅ Yes (automatic at boot) | ✅ Yes (scripted in Systemd) | ✅ Yes (ZFS auto-fetches via HTTPS) |
| **Resilience to Network Loss** | ✅ Fully independent, works offline | ❌ Unlock **fails if the SSH server is down** | ❌ Unlock **fails if the HTTPS server is down** |
| **Multiple Servers Supported?** | ❌ No, key is local per system | ✔️ Yes (SSH access per server) | ✔️ Yes (HTTPS server serves multiple clients) |
| **Performance** | 🚀 **Fastest (local file access)** | 🐌 Slower (SSH handshake 20-300ms) | 🐇 Faster (TLS session 15-200ms) |
| **Setup Complexity** | 🟢 **Simple** – just a key file ✅ | 🟡 **Medium** – requires SSH scripts ✅ | 🟠 **Complex** – HTTPS, TLS certificates ✅ |
| **Access Control** | File permissions (`chmod 600`) | SSH authorized keys | Nginx TLS authentication |
| **Logging & Auditing** | ❌ No built-in logging | ✔ Logs via `auth.log` (SSH) | ✔ Logs via `access.log` (Nginx) |
| **Failsafe if Remote Key Server is Down?** | **Always works (offline)** ✅ | ❌ SSH not reachable → unlock fails | ❌ HTTPS not reachable → unlock fails |
| **Best For** | 🏠 **Home setups & quick implementation** | 🏢 **Business setups with a separate key server** | 🏢 **Enterprise with strict SSL security** |

---




# **1️⃣ Simplest: Local File-Based Auto-Unlock**
✅ **Best if**:
- You want **the easiest setup**.
- You **trust** local file security and **restrict root access**.
- The **server will never boot in an untrusted environment**.

---

### **🛠 How It Works**
1. The **ZFS encryption key is stored locally** (e.g., `/etc/zfs/keys/zfs-dataset.key`).
2. ZFS **automatically loads the key** at boot.
3. The dataset mounts without user interaction.

🔹 **Example Configuration (In provided Script)**
```bash
zfs set keylocation=file:///etc/zfs/keys/zfs-dataset.key pool/encrypted
```

### More in the readme for related script sub-section
---


### **🌍 Pros & Cons of Local File-Based Unlock**
✅ Pros:

✔ **Easiest setup (no SSH or HTTPS required).**  
✔ **Fastest unlock method (local file access).**  
✔ **Works with Systemd auto-mounting.**  
✔ **No network dependency – works offline.**  

⚠️ Cons:

❌ **The key exists on disk in plaintext** (even with `chmod 600` restrictions).  
❌ **If an attacker gains root access, they can easily read it**.  
❌ **Not ideal if running in an untrusted environment.**  

---





# **2️⃣ SSH-Based Auto-Unlock**
✅ **Best if**:
- You **want remote key storage** but **don’t want to configure HTTPS/TLS** or you **already use SSH authentication**.
- You have **multiple ZFS servers needing the same key**.
- **You trust the key server to always be online.**

---

### **🛠 How It Works**
1. A Systemd service runs on boot.
2. It **SSH’s into the key server** and gets the encryption key.
3. It **pipes the key into `zfs load-key`** to unlock the dataset.

🔹 **Example Systemd Service:**
```bash
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'ssh -q user@keyserver "cat /path/to/zfs-keys/zfs-dataset.key" | zfs load-key pool/encrypted'
RemainAfterExit=yes
```

---

### **🌍 Pros & Cons of SSH Auto-Unlock**
✅ Pros:

✔ **No key lives permanently on the ZFS server.**  
✔ **Uses strong SSH authentication (public keys).**  
✔ **Works across multiple ZFS hosts.**  

⚠️ Cons:

❌ **If the SSH server is down, automatic unlock fails.**  
❌ **Slightly slower than a local file-based unlock.**  
❌ **Needs SSH key security best practices.**  

---




# **3️⃣ HTTPS/TLS (Client Certificate Authentication)**
✅ **Best if**:
- You want a **highly secure, scalable, centralized** system.
- You have **multiple ZFS servers needing the same key**.
- You only want **TLS-authenticated systems** to fetch the key.

---

### **🛠 How It Works**
1. **ZFS fetches the key** over `https://yourserver.com/zfs-key`
2. The server **authenticates the request via TLS certificates.**
3. If authentication passes, **it returns the key**.
4. ZFS auto-loads the key and mounts the dataset.

🔹 **Example ZFS Configuration**
```bash
zfs set keylocation=https://yourserver.com/zfs-keys/zfs-dataset.key pool/encrypted
```

### **🌍 Pros & Cons of TLS Key Fetching**
✅ Pros:

✔ **Gold-standard security:** TLS encryption + authentication.  
✔ **Centralized: Manage keys in one place across multiple servers.**  
✔ **Flexible: Works over LAN/WAN as long as HTTPS is available.**  

⚠️ Cons:

❌ **More complex to set up (requires certificates, Nginx).**  
❌ **If the HTTPS server is down, unlock fails.**  
❌ **SSL certificates need renewal (Let's Encrypt helps automate this).**  


## **🔒 How to set up TLS Client Certificate Authentication for Best Security**
This ensures **only servers with an approved certificate can access the key**.

### **Step 1: Generate a Self-Signed CA Certificate**
On the **Raspberry Pi or key server**:
```bash
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

openssl genpkey -algorithm RSA -out ca.key
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=ZFSKeyCA"
```

### **Step 2: Generate a Certificate for Proxmox**
```bash
openssl genpkey -algorithm RSA -out proxmox.key
openssl req -new -key proxmox.key -out proxmox.csr -subj "/CN=ProxmoxServer"
openssl x509 -req -in proxmox.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out proxmox.crt -days 365
```
Distribute `proxmox.key` and `proxmox.crt` to **Proxmox/Debian**.

### **Step 3: Configure Nginx to Require Client Certificates**
Edit `/etc/nginx/sites-available/default`:
```nginx
server {
    listen 443 ssl;
    server_name zfs-key-server.local;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    ssl_client_certificate /etc/nginx/ssl/ca.crt;
    ssl_verify_client on;

    location /zfs-keys/ {
        root /var/www;
    }
}
```
Reload Nginx:
```bash
sudo systemctl restart nginx
```

### **Step 4: Fetch Key Securely from Proxmox**
```bash
curl --cert /etc/ssl/proxmox.crt --key /etc/ssl/proxmox.key https://zfs-key-server.local/zfs-keys/zfs-encrypted.key
```

✔️ **Only approved Proxmox/Debian servers (with the signed cert) can access the encryption keys!**  

---

## ✅ **Final Steps**
### **1️⃣ Update ZFS to Auto-Fetch Key at Boot**
Once authentication is in place, set the dataset to fetch its key from the **secured** server:
```bash
zfs set keylocation=https://zfs-key-server.local/zfs-keys/zfs-encrypted.key "${selected_pool}/${dataset_name}"
```

### **2️⃣ Enable Auto-Unlock with Systemd**
```bash
sudo systemctl enable zfs-load-key@${dataset_name}.service
```
