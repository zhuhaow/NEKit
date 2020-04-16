# NEKit

NEKit is deprecated.

It should still work but I'm not intent on maintaining it anymore. It has many
flaws and needs a revamp to be a high-quality library.

The architecture of NEKit is not ideal due to my lack of experience when I was
writing it. To make it worse, it's not in its most efficient form as there
wasn't a good async io library while people abuse it for simple features that
should be just implemented directly or use other lightweight libraries.

NEKit is not, was never intended, and probably will never become a library that
simply works correctly out-of-the-box without understanding what it is doing
under the hook. Through all these years, one thing I learned is for some function
this low level, the developer should understand what oneself is doing. I'm
always concerned that people are creating apps that slowing down users' phones
unnecessarily because of this library and I feel responsible.

Thanks for everyone who has contributed, used or interested in this library.

## License

Copyright (c) 2016, Zhuhao Wang
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

- Neither the name of NEKit nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
