#! /bin/bash
kill -9 $(ps aux | grep attacker|grep -v "grep"|awk '{print $2}')
ps aux | grep "attacker"
