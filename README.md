# zhexdump

A tool that does almost same job as hexdump but faster ;).

(Note this is not a professional tool but just a fun side project I made to get to know zig better)

Just a time comparision b/w zhexdump,xxd and hexdump performing on a 500MB file.
(Spoiler alert and I beat both of them) {Regretably only on linux macos has some wired issue with syscalls for some reason}

Linux (Winner -> me ;)
```
@phantom2152 ➜ /workspaces/codespaces-blank/zhexdump (master) $ time xxd huge_500M.txt > /dev/null

real    0m13.067s
user    0m12.256s
sys     0m0.541s
@phantom2152 ➜ /workspaces/codespaces-blank/zhexdump (master) $ time hexdump -C huge_500M.txt > /dev/null

real    1m17.599s
user    1m15.995s
sys     0m0.686s
@phantom2152 ➜ /workspaces/codespaces-blank/zhexdump (master) $ time ./zig-out/bin/zhexdump -C huge_500M.txt > /dev/null

real    0m10.742s
user    0m9.901s
sys     0m0.633s
@phantom2152 ➜ /workspaces/codespaces-blank/zhexdump (master) $ time ./zig-out/bin/zhexdump -C huge_500M.txt > /dev/null

real    0m10.687s
user    0m9.855s
sys     0m0.617s
```

macos (Bad syscalls for some reson I honestly don't know)
```
➜  zhexdump git:(master) time hexdump -C test/500M.txt > /dev/null 
hexdump -C test/500M.txt > /dev/null  75.32s user 0.44s system 99% cpu 1:16.06 total
➜  zhexdump git:(master) time xxd  test/500M.txt > /dev/null 
xxd test/500M.txt > /dev/null  11.82s user 0.17s system 99% cpu 12.048 total
➜  zhexdump git:(master) time ./zig-out/bin/zhexdump  test/500M.txt > /dev/null 
./zig-out/bin/zhexdump test/500M.txt > /dev/null  6.23s user 8.14s system 99% cpu 14.436 total
```
