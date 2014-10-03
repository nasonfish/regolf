## regolf

This is a simple IRC bot in Perl, made to manage regex golf games through IRC.

Typically, two sets of words will be picked, possibly similar words, and people will have to come up with the shortest regex possible to match all of the words in the first set but not in the second set.

This is currently in progress and is not fully-featured yet.

## Install

We're not extremely configurable, but there's some things you can do to get this working for yourself.

 - You should fill pwd.txt with your NickServ account password. There is currently no way to turn this off.

 - After downloading, please execute:

```bash
sudo apt-get install libpoe-component-sslify-perl
sudo apt-get install wamerican  # if you don't have a wordlist
sudo apt-get install libbot-basicbot-perl
```

This should install all our dependancies.
