FROM ubuntu:focal

LABEL author = NILSHALLEN

ARG R_VERSION
ENV R_VERSION ${R_VERSION:-4.0.3}
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV PYTHON_VERSION ${PYTHON_VERSION:-3.9}

#Compiling R from source for specified
RUN DEBIAN_FRONTEND=noninteractive    
RUN apt-get update -y    
RUN DEBIAN_FRONTEND=noninteractive  \ 
    apt-get install -y build-essential \
        xorg-dev \
        liblzma-dev \
        libblas-dev \
        gfortran \
        gobjc++ \
        aptitude \
        libreadline-dev \
        libbz2-dev \
        libpcre2-dev \
        libcurl4 \
        libcurl4-openssl-dev \
        wget \
        bash && \
    cd /tmp && \
    # Download source code
    wget https://cran.r-project.org/src/base/R-${R_VERSION%%.*}/R-${R_VERSION}.tar.gz && \
    # Extract source code
    tar -xf R-${R_VERSION}.tar.gz && \
    cd R-${R_VERSION} && \
    # configure script options
    ./configure --prefix=/usr \
                --sysconfdir=/etc/R \
                --localstatedir=/var \
                rdocdir=/usr/share/doc/R \
                rincludedir=/usr/include/R \
                rsharedir=/usr/share/R \
                --enable-memory-profiling \
                --enable-R-shlib \
                --disable-nls \
                --with-blas \
                --without-recommended-packages && \
    # Build and install R
    make -j $(nproc) && \
    make install && \
    cd src/nmath/standalone && \
    make -j $(nproc) && \
    make install && \
    rm -f /usr/lib/R/bin/R && \
    ln -s /usr/bin/R /usr/lib/R/bin/R && \
    # Fix library path
    echo "R_LIBS_SITE=\${R_LIBS_SITE-'/usr/lib/R/library'}" >> /usr/lib/R/etc/Renviron && \
    # Add default CRAN mirror
    echo "options(repos = c(CRAN = 'https://cran.r-project.org'))" >> /usr/lib/R/etc/Rprofile.site && \
    # Add symlinks for the config ifile in /etc/R
    mkdir -p /etc/R && \
    ln -s /usr/lib/R/etc/* /etc/R/ && \
    # Add library directory
    mkdir -p /usr/lib/R/site-library && \
    # Strip libs
    strip -x /usr/lib/R/bin/exec/R && \
    strip -x /usr/lib/R/lib/* && \
    find /usr/lib/R -name "*.so" -exec strip -x {} \; && \
    # Clean up
    rm -rf /R-${R_VERSION}* && \
    rm -rf /usr/lib/R/library/translations && \
    rm -rf /usr/lib/R/doc && \
    mkdir -p /usr/lib/R/doc/html && \
    touch /usr/lib/R/doc/html/R.css && \
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt remove python -y
RUN apt-get install -y python${PYTHON_VERSION} \
    tini \
    python3-pip

RUN mkdir "/home/work"

RUN pip install jupyterlab

EXPOSE 8888

COPY *requirements.txt ${HOME}


RUN pip install -r python_requirements.txt || true

RUN R -e "install.packages(c('Require', 'IRkernel'))"

RUN R -e "Require::Require(packageVersionFile = 'R_requirements.txt')"
RUN R -e "IRkernel::installspec()"

ENTRYPOINT ["tini", "-g", "--"]
CMD ["jupyter-lab", "--port=8888","--allow-root", "--ip=0.0.0.0"]

WORKDIR "${HOME}"