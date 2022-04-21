#!/bin/sh -e

jwt-util generate-keys /files
jwt-util generate-jwt /files > /files/jwt.token