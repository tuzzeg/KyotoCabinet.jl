using BinDeps

@BinDeps.setup

deps = [
  libkyotocabinet = library_dependency("libkyotocabinet", aliases = ["libkyotocabinet", "libkyotocabinet16"])
]

@osx_only begin
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

builddir = joinpath(BinDeps.depsdir(libkyotocabinet), "usr")
srcdir = joinpath(BinDeps.depsdir(libkyotocabinet), "src", "kyotocabinet-$(lib_kc_ver)")
provides(SimpleBuild,
  (@build_steps begin
    GetSources(libkyotocabinet)
    CreateDirectory(builddir)
    @build_steps begin
      ChangeDirectory(srcdir)
      (@build_steps begin
        `./configure --prefix=$(builddir)`
        `make install`
      end)
    end
  end), libkyotocabinet, os = :Unix)

@BinDeps.install [:libkyotocabinet => :libkyotocabinet]
