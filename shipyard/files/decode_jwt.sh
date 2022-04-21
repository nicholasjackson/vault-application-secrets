#!/bin/sh -e

if [ "$(uname -m)" = "x86_64" ]; then
  cat /files/jwt.token | /jwt/bin/linux_amd64/jwt decode-jwt -
fi

if [ "$(uname -m)" = "arm64" ]; then
  cat /files/jwt.token | /jwt/bin/linux_arm64/jwt decode-jwt -
fi