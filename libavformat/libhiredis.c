/*
 * Copyright (c) 2022 MolotovTv
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include <hiredis/hiredis.h>
#include <sys/time.h>
#include "libavutil/opt.h"
#include "libavutil/parseutils.h"
#include "avformat.h"
#include "url.h"
#include "urldecode.h"

typedef struct {
    const AVClass *class;
    redisContext *ctx;
    char *key;
    int append;
    int64_t timeout;
    int64_t ttl;
} LIBHIREDISContext;

#define STR_LEN 1024

#define DEFAULT_IP      "127.0.0.1"
#define DEFAULT_PORT    6379
#define DEFAULT_TIMEOUT 500000

#define COMMAND_APPEND "APPEND"
#define COMMAND_SET    "SET"
#define COMMAND_EXPIRE "EXPIRE"

#define OFFSET(x) offsetof(LIBHIREDISContext, x)
#define D AV_OPT_FLAG_DECODING_PARAM
#define E AV_OPT_FLAG_ENCODING_PARAM
static const AVOption options[] = {
    { "timeout", "Set timeout (in microseconds) of socket I/O operations", OFFSET(timeout), AV_OPT_TYPE_INT64, { .i64 = -1 }, -1, INT64_MAX, .flags = D | E },
    { "ttl",     "Time to live (in seconds) of redis key",                 OFFSET(ttl),     AV_OPT_TYPE_INT64, { .i64 = 0 },  0,  INT64_MAX, .flags = D | E },
    { NULL }
};

static int libhiredis_open(URLContext *h, const char *uri, int flags)
{
    char hostname[STR_LEN], path[STR_LEN], buf[STR_LEN];
    int port;
    const char *ip;
    char *p;
    struct timeval tval = { 0 };
    LIBHIREDISContext *r = h->priv_data;

    if (flags & AVIO_FLAG_READ) {
        av_log(h, AV_LOG_ERROR, "Redis read not supported yet.\n");
        return AVERROR(EINVAL);
    }
    /* Init */
    r->append = 0;
    /* Parse URI */
    av_url_split(NULL, 0, NULL, 0, hostname, sizeof(hostname),
                 &port, path, sizeof(path), uri);
    /* IP */
    if (*hostname == '\0')
        ip = DEFAULT_IP;
    else
        ip = hostname;
    /* Port */
    if (port < 0)
        port = DEFAULT_PORT;
    if (port <= 0 || port > 65535 ) {
        av_log(h, AV_LOG_ERROR, "Invalid port\n");
        return AVERROR(EINVAL);
    }
    /* Key */
    if (*path == '\0' || *(path + 1) == '\0') {
        av_log(h, AV_LOG_ERROR, "No key\n");
        return AVERROR(EINVAL);
    }
    p = strchr(path, '?');
    if (p)
        *p = '\0';
    r->key = ff_urldecode(path + 1, 0); /* skip leading '/' */
    if (!r->key)
        return AVERROR(ENOMEM);
    /* Options */
    p = strchr(uri, '?');
    if (p) {
        if (av_find_info_tag(buf, sizeof(buf), "timeout", p))
            r->timeout = strtol(buf, NULL, 10);
        if (av_find_info_tag(buf, sizeof(buf), "ttl", p))
            r->ttl = strtol(buf, NULL, 10);
    }
    if (r->timeout < 0)
        r->timeout = DEFAULT_TIMEOUT;
    /* Redis connect */
    tval.tv_sec  = r->timeout / 1000000;
    tval.tv_usec = r->timeout % 1000000;
    r->ctx = redisConnectWithTimeout(ip, port, tval);
    if (r->ctx == NULL || r->ctx->err) {
        av_free(r->key);
        if (r->ctx) {
            av_log(h, AV_LOG_ERROR, "Error connect: %s\n", r->ctx->errstr);
            redisFree(r->ctx);
            return AVERROR_EXTERNAL;
        }
        return AVERROR(ENOMEM);
    }
    /* Command timeout */
    if (redisSetTimeout(r->ctx, tval) != REDIS_OK) {
        if (r->ctx->err)
            av_log(h, AV_LOG_ERROR, "Error set timeout: %s\n", r->ctx->errstr);
        av_free(r->key);
        redisFree(r->ctx);
        return AVERROR_EXTERNAL;
    }

    return 0;
}

static int libhiredis_write(URLContext *h, const uint8_t *buf, int size)
{
    LIBHIREDISContext *r = h->priv_data;
    const char *command;
    redisReply *reply;

    if (r->append)
        command = COMMAND_APPEND;
    else
        command = COMMAND_SET;
    /* Redis command */
    reply = redisCommand(r->ctx, "%s %s %b", command, r->key, buf, (size_t)size);
    if (!reply) {
        if (r->ctx->err == REDIS_ERR_IO)
            return AVERROR(EIO);
        if (r->ctx->err == REDIS_ERR_TIMEOUT)
            return AVERROR(EAGAIN);
        return AVERROR(ENOMEM);
    } else if (reply->type == REDIS_REPLY_ERROR) {
        av_log(h, AV_LOG_ERROR, "Error command (%s): %s\n", command, reply->str);
        freeReplyObject(reply);
        return AVERROR_EXTERNAL;
    }
    /* Ok */
    freeReplyObject(reply);
    r->append = 1;

    return size;
}

static int libhiredis_close(URLContext *h)
{
    LIBHIREDISContext *r = h->priv_data;
    redisReply *reply;

    /* TTL / Redis EXPIRE command */
    if (r->ttl > 0) {
        reply = redisCommand(r->ctx, "%s %s %d", COMMAND_EXPIRE, r->key, r->ttl);
        if (!reply) {
            if (r->ctx->err == REDIS_ERR_IO)
                return AVERROR(EIO);
            if (r->ctx->err == REDIS_ERR_TIMEOUT)
                return AVERROR(EAGAIN);
            return AVERROR(ENOMEM);
        } else if (reply->type == REDIS_REPLY_ERROR) {
            av_log(h, AV_LOG_ERROR, "Error command (%s): %s\n", COMMAND_EXPIRE, reply->str);
            freeReplyObject(reply);
            return AVERROR_EXTERNAL;
        }
        /* Ok */
        freeReplyObject(reply);
    }

    av_free(r->key);
    redisFree(r->ctx);

    return 0;
}

static const AVClass libhiredis_context_class = {
    .class_name = "libhiredis",
    .item_name  = av_default_item_name,
    .option     = options,
    .version    = LIBAVUTIL_VERSION_INT,
};

const URLProtocol ff_libhiredis_protocol = {
    .name            = "redis",
    .url_open        = libhiredis_open,
    .url_write       = libhiredis_write,
    .url_close       = libhiredis_close,
    .priv_data_size  = sizeof(LIBHIREDISContext),
    .priv_data_class = &libhiredis_context_class,
    .flags           = URL_PROTOCOL_FLAG_NETWORK,
};
