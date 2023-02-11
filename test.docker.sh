#/bin/bash
docker run -t -v $PWD:/home -w /home swift:5.7 /bin/bash -c ./test.sh
