FROM ubuntu:14.04

ENV JULIAVERSION juliareleases

RUN \
  apt-get update -qq -y && \
  apt-get install -y \
    software-properties-common\
    python-software-properties && \
  add-apt-repository ppa:staticfloat/julia-deps -y && \
  add-apt-repository ppa:staticfloat/${JULIAVERSION} -y

RUN \
  apt-get update -qq -y && \
  apt-get install -y \
    gcc \
    libpcre3-dev \
    curl \
    julia

RUN \
  apt-get install -y \
    libkyotocabinet-dev

RUN \
  julia --version && \
  julia -e 'Pkg.init()' && \
  julia -e 'Pkg.clone("https://github.com/tuzzeg/KyotoCabinet.jl")' && \
  julia -e 'Pkg.build("KyotoCabinet")' && \
  julia -e 'Pkg.test("KyotoCabinet")'

CMD ["julia"]
