#!/bin/bash

sudo find / -type f -size +100M -exec du -ah {} + | sort -hr | head -10