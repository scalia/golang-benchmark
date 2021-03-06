#!/usr/bin/env bash

if [ $# -ne 1 ]
then
    echo "Usage: $0 path-to-dists."
    exit 1
fi

passes=3
prefix=results_$RANDOM
benchtime=2

goversions=""
benchmarks=""
for pass in `seq 1 $passes`
do
    for i in "$1"/*
    do
        export GOROOT="$i"
        gobin="$i/bin/go"
        goversion=`"$gobin" version | cut -f3 -d' '`
        goversions="$goversions$goversion\n"
        echo `date` "[PASS $pass of $passes] Executing benchmarks for $goversion..."
        for bench in `("$gobin" test -bench=. -benchtime=$benchtime || "$gobin" test -bench=. -benchtime=${benchtime}s) 2>&1 | grep '^Benchmark.*ns/op$' | sort | tr -s '[:blank:]' '=' | cut -f1,3 -d'='`
        do
            name=`echo $bench | cut -f1 -d'='`
            time=`echo $bench | cut -f2 -d'=' | cut -f1 -d.`
            benchmarks="$benchmarks$name\n"
            let ${prefix}_${goversion//./_}_${name}+=$time
        done
    done
done
goversions=(`echo -ne $goversions | sort | uniq | tr "\n" ' '`)
benchmarks=(`echo -ne $benchmarks | sort | uniq | tr "\n" ' '`)

echo `date` "Processing results..."
mkdir -p results
tmpfile=`tempfile`
for benchmark in ${benchmarks[@]}
do
    benchmark=${benchmark#Benchmark}
    echo '"'$benchmark'"' > results/${benchmark}.dat
    for goversion in ${goversions[@]}
    do
        time=`set | grep "^${prefix}_"${goversion//./_}_Benchmark${benchmark}= | cut -f2 -d=`
        let time=$time/$passes
        echo $goversion $time >> results/${benchmark}.dat
    done

    OUTPUT=results/${benchmark} YLABEL='Time (ns)' DATAFILE=results/${benchmark}.dat . benchmark.gp.sh > $tmpfile
    gnuplot $tmpfile
done

echo '"Sum"' > results/sum.dat
for goversion in ${goversions[@]}
do
    totaltime=0
    for benchmark in ${benchmarks[@]}
    do
        time=`set | grep "^${prefix}_"${goversion//./_}_${benchmark}= | cut -f2 -d=`
        let totaltime=$totaltime+$time
    done
    echo $goversion $totaltime >> results/sum.dat
done
OUTPUT=results/sum YLABEL='Time (ns)' DATAFILE=results/sum.dat . benchmark.gp.sh > $tmpfile
gnuplot $tmpfile

echo '"Score"' > results/total.dat
for goversion in ${goversions[@]}
do
    totaltime=0
    for benchmark in ${benchmarks[@]}
    do
        maxtime=0
        for v in ${goversions[@]}
        do
            time=`set | grep "^${prefix}_"${v//./_}_${benchmark}= | cut -f2 -d=`
            if [ $time -gt $maxtime ]
            then
                maxtime=$time
            fi
        done
        time=`set | grep "^${prefix}_"${goversion//./_}_${benchmark}= | cut -f2 -d=`
        let totaltime="$totaltime+((${time}*1000)/${maxtime})"
    done
    echo $goversion $totaltime >> results/total.dat
done
OUTPUT=results/total YLABEL='Score' DATAFILE=results/total.dat . benchmark.gp.sh > $tmpfile
gnuplot $tmpfile

rm $tmpfile

echo `date` "All done."
