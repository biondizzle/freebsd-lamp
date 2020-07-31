# freebsd-lamp
some tools to quickly deploy lamp stack on freebsd

install bash, wget, and nano
```
pkg install bash wget nano
```

download and open in nano
```
wget --no-check-certificate https://raw.githubusercontent.com/biondizzle/freebsd-lamp/master/install.sh
nano install.sh
```

edit the following lines

```
# User Password
user_name="ADD_YOUR_USERNAME_HERE"
user_password="ADD_YOUR_PASSWORD_HERE"
```

add execution permission and run

```
chmod +x ./install.sh
./install.sh
```
