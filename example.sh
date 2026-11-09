#!/bin/sh

set -u

wsm="./arrow-ipc2resized.wasm"

iarrow="./in.arrow.ipc.stream.dat"

run_wasmtime() {
	cat /dev/stdin |
		wasmtime \
			run \
			--env ENV_BAT_SIZE=1 \
			"${wsm}"
}

run_wasi() {
	run_wasmtime
}

csv2ipc(){
  imports=""
  imports="${imports}import functools;"
  imports="${imports}import sys;"
  imports="${imports}import pyarrow as pa;"
  imports="${imports}import pyarrow.csv as pc;"

  cat /dev/stdin |
    python3 -c "${imports}"'functools.reduce(
      lambda state,f: f(state),
      [
        pc.open_csv,
        lambda rdr: (
          pa.ipc.new_stream(sys.stdout.buffer, rdr.schema),
          rdr,
        ),
        lambda pair: map(
          pair[0].write_batch,
          pair[1],
        ),
        lambda writes: sum(1 for _ in writes),
        lambda _: sys.stdout.buffer.flush(),
      ],
      sys.stdin.buffer,
    )'
}

icsv(){
  echo id,timestamp,severity,body
  echo 1,333,INFO,apt update done
  echo 2,634,WARN,apt update failure
}

geninput(){
  echo creating the input arrow ipc stream...
  icsv |
    csv2ipc |
    dd bs=1048576 of="${iarrow}" status=none
}

test -f "${iarrow}" || geninput

test -f "${iarrow}" || exec env i="${iarrow}" sh -c '
  echo sample input data ${i} missing.
  exit 1
'

echo original ipc
cat "${iarrow}" | arrow-cat
echo

echo resized
cat "${iarrow}" | run_wasi | arrow-cat
echo
