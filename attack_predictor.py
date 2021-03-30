#! /usr/bin/python3
import time

cache = [0]*10
timer=0
attack_rate = 1000
attack_rate=int(attack_rate/1000)
attack_time = 9
sleep_time = 2
possible = True
Flag = 0
while(timer <= 3*(attack_time+sleep_time)):
    for i in range(len(cache)):
        if(cache[i]>0):
            cache[i]-=1

    curr = timer%(attack_time+sleep_time)
    if(curr<=attack_time and curr>0):
        attack=True
    else:
        attack=False

    if(curr==1):
        counter=1

    if(attack):
        for i in range(attack_rate):
            cache[(counter-1)%10]=10
            counter+=1
    
    empty_masks=[]
    
    for i in range(len(cache)-1):
        if(cache[i]==0):
            empty_masks.append(i+1)
    

    if(timer>(attack_time+sleep_time)):
        if(Flag>2 and len(empty_masks)==0):
            print(1)
            possible=False
            break

        if(len(empty_masks)>2 and attack==False):
            possible=False
            break

        if(len(empty_masks)==0):
            Flag+=1
        else:
            Flag=0
    
    #print(timer,cache,attack,curr)
    #time.sleep(1)
    timer+=1

print(possible)
