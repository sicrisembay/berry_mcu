#include <errno.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>

/* newlib system call stubs; _write lives in main_g474.c and _sbrk in libnosys. */

int _close(int file)
{
    (void)file;
    errno = ENOSYS;
    return -1;
}

int _fstat(int file, struct stat *st)
{
    (void)file;
    st->st_mode = S_IFCHR;
    return 0;
}

int _getpid(void)
{
    return 1;
}

int _gettimeofday(struct timeval *tv, void *tz)
{
    (void)tv;
    (void)tz;
    errno = ENOSYS;
    return -1;
}

int _isatty(int file)
{
    (void)file;
    return 1;
}

int _kill(int pid, int sig)
{
    (void)pid;
    (void)sig;
    errno = EINVAL;
    return -1;
}

int _lseek(int file, int offset, int whence)
{
    (void)file;
    (void)offset;
    (void)whence;
    errno = ENOSYS;
    return -1;
}

int _open(const char *path, int flags, ...)
{
    (void)path;
    (void)flags;
    errno = ENOSYS;
    return -1;
}

int _read(int file, char *data, int length)
{
    (void)file;
    (void)data;
    (void)length;
    errno = ENOSYS;
    return -1;
}

clock_t _times(struct tms *buffer)
{
    (void)buffer;
    errno = ENOSYS;
    return (clock_t)-1;
}
