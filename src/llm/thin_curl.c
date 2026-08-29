#include <curl/curl.h>

int coyote_abort_xfer_info (void *clientp,
                              curl_off_t dltotal,
                              curl_off_t dlnow,
                              curl_off_t ultotal,
                              curl_off_t ulnow)
{
  (void)dltotal;
  (void)dlnow;
  (void)ultotal;
  (void)ulnow;
  return clientp != NULL && *(volatile int *)clientp != 0;
}


CURLcode curl_set_url (CURL *h, const char *v)
{
  return curl_easy_setopt (h, CURLOPT_URL, v);
}

CURLcode curl_set_post (CURL *h, long v)
{
  return curl_easy_setopt (h, CURLOPT_POST, v);
}

CURLcode curl_set_postfields (CURL *h, const char *v)
{
  return curl_easy_setopt (h, CURLOPT_POSTFIELDS, v);
}

CURLcode curl_set_postfieldsize (CURL *h, long v)
{
  return curl_easy_setopt (h, CURLOPT_POSTFIELDSIZE, v);
}

CURLcode curl_set_httpheader (CURL *h, struct curl_slist *v)
{
  return curl_easy_setopt (h, CURLOPT_HTTPHEADER, v);
}

CURLcode curl_set_writefunction (CURL *h, curl_write_callback v)
{
  return curl_easy_setopt (h, CURLOPT_WRITEFUNCTION, v);
}

CURLcode curl_set_writedata (CURL *h, void *v)
{
  return curl_easy_setopt (h, CURLOPT_WRITEDATA, v);
}

CURLcode curl_set_nosignal (CURL *h, long v)
{
  return curl_easy_setopt (h, CURLOPT_NOSIGNAL, v);
}

CURLcode curl_set_noprogress (CURL *h, long v)
{
  return curl_easy_setopt (h, CURLOPT_NOPROGRESS, v);
}

CURLcode curl_set_xferinfofunction (CURL *h, curl_xferinfo_callback v)
{
  return curl_easy_setopt (h, CURLOPT_XFERINFOFUNCTION, v);
}

CURLcode curl_set_xferinfodata (CURL *h, void *v)
{
  return curl_easy_setopt (h, CURLOPT_XFERINFODATA, v);
}

CURLcode curl_get_response_code (CURL *h, long *out)
{
  return curl_easy_getinfo (h, CURLINFO_RESPONSE_CODE, out);
}
