#include "stm32g4xx_hal.h"
#include "berry.h"
#include "be_repl.h"
#include "boardlib.h"
#include "shell.h"
#include <stdio.h>

static UART_HandleTypeDef console_uart;
static uint8_t received_byte;

static void error_handler(void)
{
    while (1) {
        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
        HAL_Delay(100);
    }
}

static void led_init(void)
{
    GPIO_InitTypeDef gpio = {0};

    __HAL_RCC_GPIOA_CLK_ENABLE();
    gpio.Pin = GPIO_PIN_5;
    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Pull = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOA, &gpio);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);
}

static void console_init(void)
{
    console_uart.Instance = USART2;
    console_uart.Init.BaudRate = 115200;
    console_uart.Init.WordLength = UART_WORDLENGTH_8B;
    console_uart.Init.StopBits = UART_STOPBITS_1;
    console_uart.Init.Parity = UART_PARITY_NONE;
    console_uart.Init.Mode = UART_MODE_TX_RX;
    console_uart.Init.HwFlowCtl = UART_HWCONTROL_NONE;
    console_uart.Init.OverSampling = UART_OVERSAMPLING_16;
    console_uart.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
    console_uart.Init.ClockPrescaler = UART_PRESCALER_DIV1;
    console_uart.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;

    if (HAL_UART_Init(&console_uart) != HAL_OK) {
        error_handler();
    }

    if (HAL_UART_Receive_IT(&console_uart, &received_byte, 1U) != HAL_OK) {
        error_handler();
    }
}

int _write(int file, char *data, int length)
{
    (void)file;
    for (int index = 0; index < length; ++index) {
        uint8_t character = (uint8_t)data[index];
        if (character == '\n' && (index == 0 || data[index - 1] != '\r')) {
            uint8_t carriage_return = '\r';
            if (HAL_UART_Transmit(&console_uart, &carriage_return, 1U, HAL_MAX_DELAY) != HAL_OK) {
                return -1;
            }
        }
        if (HAL_UART_Transmit(&console_uart, &character, 1U, HAL_MAX_DELAY) != HAL_OK) {
            return -1;
        }
    }
    return length;
}

int main(void)
{
    if (HAL_Init() != HAL_OK) {
        error_handler();
    }

    led_init();
    console_init();
    setvbuf(stdout, NULL, _IONBF, 0);
    board_init();
    printf("Berry " BERRY_VERSION " on STM32G474RE\r\n");
    printf("HSI: %lu Hz, USART2: 115200 baud, LED: PA5\r\n", (unsigned long)SystemCoreClock);

    bvm *vm = be_vm_new();
    be_repl(vm, shell_readline, shell_freeline);
    be_vm_delete(vm);

    while (1) {
        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
        HAL_Delay(500);
    }
}

void HAL_UART_MspInit(UART_HandleTypeDef *huart)
{
    GPIO_InitTypeDef gpio = {0};

    if (huart->Instance == USART2) {
        __HAL_RCC_GPIOA_CLK_ENABLE();
        __HAL_RCC_USART2_CLK_ENABLE();

        gpio.Pin = GPIO_PIN_2 | GPIO_PIN_3;
        gpio.Mode = GPIO_MODE_AF_PP;
        gpio.Pull = GPIO_PULLUP;
        gpio.Speed = GPIO_SPEED_FREQ_LOW;
        gpio.Alternate = GPIO_AF7_USART2;
        HAL_GPIO_Init(GPIOA, &gpio);

        HAL_NVIC_SetPriority(USART2_IRQn, 5U, 0U);
        HAL_NVIC_EnableIRQ(USART2_IRQn);
    }
}

void USART2_IRQHandler(void)
{
    HAL_UART_IRQHandler(&console_uart);
}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2) {
        shell_addchar(received_byte);
        HAL_UART_Receive_IT(huart, &received_byte, 1U);
    }
}

void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2) {
        HAL_UART_Receive_IT(huart, &received_byte, 1U);
    }
}

void SysTick_Handler(void)
{
    HAL_IncTick();
}