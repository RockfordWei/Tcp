#/bin/bash
docker run -it -v $PWD:/home -p 8080:8080 -w /home swift:5.7 /bin/bash -c ./test.sh
