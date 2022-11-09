# Creating a yubikey that allows SSH authentication with a key generated from a passphrase

This recipe provides a simple Dockerfile that allows you to generate a SSH key
from a passphrase and store the generated key on a Yubikey. This will allow you
to keep the passphrase on a piece of paper in a safe place, and generate more
such Yubikeys if you lost the first one.

Passphrase to key is done by using https://github.com/skeeto/passphrase2pgp.

## Create the yubikey from the passphrase

I'm assuming we're using the docker container, so GPG was never configured.

Reset the Yubikey. This sets the PIN to 123456, the PUK to 12345678, and the Admin PIN to 12345678.
Since we don't want a secret PIN, we'll just leave those as their default.

```
ykman piv reset
ykman openpgp reset
```

Generate the SSH key from the passphrase and user ID. Replace `KEY_UID` below. This
will ask you for the passphrase. *This is the secret passphrase*.

```
export KEY_UID=<put here something non-secret which goes into key generation, such as a username>
~/go/bin/passphrase2pgp --format ssh --uid $KEY_UID | (umask 077; tee ~/id_ed25519)
grep ssh-ed25519 ~/id_ed25519 > ~/id_ed25519.pub
```

Add the SSH private key to GPG. This will ask for a passphrase, use "1234":

(Note: this works because in the docker file we added `export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)` to `~/.bashrc`)

```
ssh-add ~/id_ed25519
```

Find the GPG key grip of the new key. This is the file name without the ".key".
(If GPG was initialized before, there will be other keys. Here I assume we're starting from scratch):

```
ls $(gpgconf --list-dirs homedir)/private-keys-v1.d
```

Generate a GPG master key. This will ask for a passphrase. Enter "1234", confirm that it's weak, and re-enter:

```
gpg --quick-generate-key 'Test User <test@example.com>' ed25519 cert,sign
```

Now add the SSH private key as a subkey of the master key.

```
gpg --expert --edit-key 'Test User <test@example.com>'
```

* With the `gpg>` prompt, run `addkey`.
* Choose `13`, for "Existing key".
* Enter the keygrip you found earlier. (eg `CE9ED57323C6D409EA113BB853DCC7BA5EF05C42`)
* Press `A` for `Toggle the authenticate capability`. 
* You should now see: `Current allowed actions: Sign Authenticate`. Press `q` to confirm.
* Press Enter for `Key is valid for? (0)`.
* Confirm twice. Enter "1234" as the passphrase twice.

Now move this key to the Yubikey!

* With the `pgp>` prompt, run `key 1`. You should see the secondary key selected - note the `*` in  `ssb*` below:

```
gpg> key 1

sec  ed25519/0D75491C23222F68
     created: 2022-11-09  expires: 2024-11-08  usage: SC  
     trust: ultimate      validity: ultimate
ssb* ed25519/F9C2B8A4125409EB
     created: 2022-11-09  expires: never       usage: SA  
[ultimate] (1). Test User <test@example.com>
```

* With the `pgp>` prompt, run `keytocard`.
* Type `3`, for "Authentication key".
* Enter the passphrase `1234`
* Enter the Admin PIN `12345678`
* Enter the Admin PIN again.
* Type `q` to quit. You're done!

## Test SSH authentication with the yubikey

Start with a new docker container, so the `~/.gnupg` directory will not include
any existing keys. Have the Yubikey connected.

Start a local SSH server, to let us check that we can connect to ourselves.

```
/usr/sbin/sshd
```

Make sure you see the key available:

```
ssh-add -L
```

You should see something like that:

```
root@40866943f54a:/# ssh-add -L
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1deq92MgUOAhpacw1LByxKmRU1To56+PettbYjD4mI cardno:000619790164
```

Add the public key to `~/.ssh/authorized_keys`:

```
ssh-add -L > ~/.ssh/authorized_keys
```

Try to SSH:

```
ssh localhost echo success
```

This will ask for the PIN. Enter `123456`.

