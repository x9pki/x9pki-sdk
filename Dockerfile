FROM ubuntu:24.10

# Fix some security issues in Ubuntu 24.10
RUN apt-get remove -y --purge \
    xz-utils

# Copy the /opt/crypto directory from the openca.org
# image (openca.org/ubuntu24-crypto:latest) to a fresh
# new ubuntum:24.04 image.
COPY --from=openca.org/ubuntu24-crypto:latest /opt/crypto /opt/crypto

# Adds the repo to the container to provide the supprt for
# key and certificate generation
COPY . /opt/crypto

# Add the /opt/crypto/bin directory to the PATH
ENV PATH="/opt/crypto/bin:${PATH}"

# Add the /opt/crypto/lib directory to the LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH="/opt/crypto/lib:${LD_LIBRARY_PATH}"

# Add the /opt/crypto/lib64 directory to the LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH="/opt/crypto/lib64:${LD_LIBRARY_PATH}"

# Sets the working directory to /opt/crypto
WORKDIR /opt/crypto

# Set the default command to run when the container starts
CMD ["/bin/bash"]
