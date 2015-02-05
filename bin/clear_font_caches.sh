#!/bin/bash

atsutil databases -removeUser
sudo atsutil databases -remove
atsutil server -shutdown
atsutil server -ping
