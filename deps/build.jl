using BinDeps

@BinDeps.setup

deps = [
  libkyotocabinet = library_dependency("libkyotocabinet", aliases = ["libkyotocabinet", "libkyotocabinet16"])
]

@osx_only begin
  if Pkg.installed("Homebrew") === nothing
    error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")
  end
  using Homebrew
  provides(Homebrew.HB, "kyotocabinet", libkyotocabinet, os = :Darwin )
end

# System Package Managers
provides(AptGet, {
  "libkyotocabinet-dev" => libkyotocabinet
})

const lib_kc_ver = "1.2.76"

provides(Sources, {
  URI("http://fallabs.com/kyotocabinet/pkg/kyotocabinet-$(lib_kc_ver).tar.gz") => libkyotocabinet
})

prefix = joinpath(BinDeps.depsdir(libkyotocabinet), "usr")
lib_kc_srcdir = joinpath(BinDeps.depsdir(libkyotocabinet), "src", "kyotocabinet-$(lib_kc_ver)")
provides(BuildProcess,
  (@build_steps begin
    GetSource(libkyotocabinet)
    CreateDirectory(prefix)
    @build_steps begin
      ChangeDirectory(lib_kc_srcdir)
      FileRule(joinpath(prefix, "lib", "libkyotocabinet.so"), @build_steps begin
        `./configure --prefix=$(prefix)`
        `make`
        `make install`
      end)
    end
  end), libkyotocabinet, os = :Unix)

@BinDeps.install [:libkyotocabinet => :libkyotocabinet]
