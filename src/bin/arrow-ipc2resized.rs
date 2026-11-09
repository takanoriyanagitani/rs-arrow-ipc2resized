use std::io;
use std::process::ExitCode;

use rs_arrow_ipc2resized::BATCH_SIZE_DEFAULT;
use rs_arrow_ipc2resized::Config;

fn io_envkey2val(key: &'static str) -> impl FnMut() -> Result<String, io::Error> {
    move || std::env::var(key).map_err(io::Error::other)
}

fn string2usize(s: String) -> Result<usize, io::Error> {
    str::parse(&s).map_err(io::Error::other)
}

fn io_batch_size() -> impl FnMut() -> usize {
    || {
        let s: String = io_envkey2val("ENV_BAT_SIZE")().unwrap_or_default();
        let u: usize = string2usize(s).ok().unwrap_or(BATCH_SIZE_DEFAULT);
        u
    }
}

fn io_config() -> impl FnMut() -> Config {
    || {
        let target_size: usize = io_batch_size()();
        Config { target_size }
    }
}

fn io_main() -> impl FnOnce() -> Result<(), io::Error> {
    || {
        let cfg: Config = io_config()();
        cfg.stdin2istrm2resized2stdout()
    }
}

fn sub() -> Result<(), io::Error> {
    io_main()()
}

fn main() -> ExitCode {
    sub().map(|_| ExitCode::SUCCESS).unwrap_or_else(|e| {
        eprintln!("{e}");

        let cfg: Config = io_config()();

        let Config { target_size } = cfg;

        eprintln!("ENV_BAT_SIZE: {target_size}");

        ExitCode::FAILURE
    })
}
