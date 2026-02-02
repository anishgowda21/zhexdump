# zhexdump

A tool that does almost same job as hexdump but faster ;).

(Note this is not a professional tool but just a fun side project I made to get to know zig better)

Just a time comparision b/w zhexdump and hexdump performing on a 6MB file.

```
➜  zhexdump git:(master) ✗ time ./zig-out/bin/zhexdump pg100.txt > /dev/null
./zig-out/bin/zhexdump pg100.txt > /dev/null  0.06s user 0.09s system 98% cpu 0.154 total
➜  zhexdump git:(master) ✗ time ./zig-out/bin/zhexdump pg100.txt > /dev/null
./zig-out/bin/zhexdump pg100.txt > /dev/null  0.06s user 0.09s system 99% cpu 0.154 total
➜  zhexdump git:(master) ✗ time hexdump pg100.txt > /dev/null
hexdump pg100.txt > /dev/null  0.31s user 0.00s system 99% cpu 0.318 total
➜  zhexdump git:(master) ✗ time hexdump pg100.txt > /dev/null
hexdump pg100.txt > /dev/null  0.31s user 0.00s system 99% cpu 0.314 total
➜  zhexdump git:(master) ✗ time hexdump pg100.txt > /dev/null
hexdump pg100.txt > /dev/null  0.31s user 0.00s system 99% cpu 0.314 total
➜  zhexdump git:(master) ✗ 
```