using BinDeps

@BinDeps.setup

deps = [
  libkyotocabinet = library_dependency("kyotocabinet", aliases = ["libkyotocabinet", "libkyotocabinet16"])
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

provides(Sources, {
  URI("http://fallabs.com/kyotocabinet/pkg/kyotocabinet-1.2.76.tar.gz") => libkyotocabinet
})

provides(BuildProcess, {
  Autotools(libtarget = "libkyotocabinet.la") => libkyotocabinet,
})
