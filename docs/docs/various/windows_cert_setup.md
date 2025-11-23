In order to install from an msix, windows requires it to be signed.
The following summarized very briefly on how to generate a certificate on linux for signing (via the action).


Generate the base pem.
```
openssl genrsa -out zest.pem 2048
```

Following generates a certificate that is valid for 3 years. Pay attention to the CN.
```
openssl req -x509 -new -nodes \
  -key zest.pem \
  -sha256 \
  -days 1095 \
  -out zest.crt \
  -subj "/CN=com.dbadrian.zest"
```


Generate the pfx, which is used in conjunction with the sign tool.
```
openssl pkcs12 -export \
  -out zest.pfx \
  -inkey zest.pem \
  -in zest.crt

```

Note: Password is in password safe

Convert to base64 and clip board -> github actions secret
```
base64 -i zest.pfx > base64pfx && xclip -sel c < base64pfx
```