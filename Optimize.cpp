#include <sys/types.h>
#include <unistd.h>

#include <stdlib.h>

int main(int argc, char *argv[]) {
    setuid(0);
    setgid(0);

    system("/usr/bin/find -L /Library/Themes/ -name '*.png' -not -xtype l -print0 | /usr/bin/xargs -0 pincrush -i");

    return 0;
}
