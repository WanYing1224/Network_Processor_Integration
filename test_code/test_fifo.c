#include <stdint.h>

int main() {
    volatile uint32_t *fifo_ctrl = (volatile uint32_t *)0x80001000;
    volatile uint32_t *fifo_stat = (volatile uint32_t *)0x80001004;
    volatile uint32_t *fifo_data = (volatile uint32_t *)0x80000000;
    volatile uint32_t *gpu_data  = (volatile uint32_t *)0x81000000;
    volatile uint32_t *gpu_ctrl  = (volatile uint32_t *)0x81001000;

    *fifo_ctrl = 1;

    while (*fifo_stat != 1) {

    }

    uint32_t payload = *fifo_data;
    *gpu_data = payload;
    *gpu_ctrl = 1;
    uint32_t result = *gpu_data;
    *fifo_data = result;
    *fifo_ctrl = 0;

    while (1) {

    }

    return 0;
}
