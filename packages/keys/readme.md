### 1. 放key的⽬录：keys

```bash
mkdir -p keys && cd keys
rk_sign_tool cc --chip 3588
rk_sign_tool kk --out .
```

### 2. 使⽤RK的"rk_sign_tool"⼯具⽣成RSA2048的私钥 privateKey.pem 和 publicKey.pem（请参考 rk_sign_tool 的使⽤⼿册），分别更名存放为：keys/dev.key 和 keys/dev.pubkey

```bash
mv private_key.pem dev.key
mv public_key.pem  dev.pubkey
```

### 3. 使⽤-x509和私钥⽣成⼀个⾃签名证书：keys/dev.crt （效果本质等同于公钥）
```bash
openssl req -batch -new -x509 -key dev.key -out dev.crt
```

### rk_sign_tool

#### rk_sign_tool is a signing tool for secureboot.it can support
show help of the tool.run it with any parameters.show detail of command,run the command with -h.

```bash
build/rkbin/tools/rk_sign_tool -h
********sign_tool ver 1.4********
```

#### step by step:
##### 1.specify chip,just do it once, all of chips are     
- RK3588
- RK3566
- RK3568
- RK3308
- RK3326
- RK3399
- RK3229
- RK3228H
- RK3368
- RK3228
- RK3288
- PX30
- RK3328
- RK1808
- RK3228P
- RK1109
- RK1126
- RK2206

```bash
rk_sign_tool cc --chip 3588
```

##### 2.generate rsa key pairs ,just do it once.if you have key pairs generated before ,go next

```bash
rk_sign_tool kk --out .
```

##### 3.load rsa key pairs,just do it onece . if you have key pairs loaded before, go next
```bash
rk_sign_tool lk --key privateKey.pem --pubkey publicKey.pem
```

##### 4.sign loader
```bash
rk_sign_tool sl --loader loader.bin
```

##### 5.sign uboot.img trust.img

```bash
rk_sign_tool si --img uboot.img
rk_sign_tool si --img trust.img
```

##### 6.sign update.img,it will sign loader,uboot,trust in the update.img

```bash
rk_sign_tool sf --firmware update.img
```