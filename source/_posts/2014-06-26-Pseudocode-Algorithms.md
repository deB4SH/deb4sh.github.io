---
title: Pseudocode for some basic Algorithms
date: 2014-06-26 00:00
comments: false
tags: 
- pseudocode
- study times
- study
- algorithmic
- fh stralsund
---

Hello everyone, I am currently in my final learning phase for exams and stumbled about the topic, writing pseudocode for simple algorithms like selectsort,insertsort or bubblesort. I though about an hour of all three to get a nice and clean version done. I know there are "ready to use"-stuff on Wikipedia or other bulletin -boards... but to get an own version is somehow cool :) 

### SelectSort
``` shell
selectSort(Array a){
    i = 0
    l = a.length()
    while(i <length){
        min = i
        for(j = i+1; j <= n; j++){
            if(a[j] < a[min]){
                min = j
            }
        }
    a.switch(i,min)
    }
}
```

### InsertSort
```shell
insertSort(Array a){
    n = a.length()
    i = 0
    while(i<n){
        for(j=n-1; j>0; j--){
            if(a[j-1] > a[j]){
                val = a[j]
                a[j] = a[j-1]
                a[j-1] = val
            }
        }
    i++
}
```

### BubbleSort
```shell
bubbleSort(Array a){
    n = a.length()
    while(n>1){
        for(i=0; i < n-1; i++){
        if(a[i] > a[i+1]){
            a.switch(i,i+1)
        }
    }
    n--
}
```