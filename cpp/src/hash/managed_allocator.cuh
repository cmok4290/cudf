/*
 * Copyright (c) 2017, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef MANAGED_ALLOCATOR_CUH
#define MANAGED_ALLOCATOR_CUH

#include <new>

#include <rmm/rmm.h>
#include <rmm/mr/device_memory_resource.hpp>
#include <rmm/mr/managed_memory_resource.hpp>

template <class T>
struct managed_allocator {
      typedef T value_type;
      rmm::mr::device_memory_resource* mr = new rmm::mr::managed_memory_resource;

      managed_allocator() = default;

      template <class U> constexpr managed_allocator(const managed_allocator<U>&) noexcept {}
      
      T* allocate(std::size_t n, cudaStream_t stream = 0) const {
          return (T*)mr->allocate( n*sizeof(T), stream );
      }

      void deallocate(T* p, std::size_t n, cudaStream_t stream = 0) const {
          mr->deallocate( p, n*sizeof(T), stream );
      }
};

template <class T, class U>
bool operator==(const managed_allocator<T>&, const managed_allocator<U>&) { return true; }
template <class T, class U>
bool operator!=(const managed_allocator<T>&, const managed_allocator<U>&) { return false; }

template <class T>
struct legacy_allocator {
      typedef T value_type;

      legacy_allocator() = default;

      template <class U> constexpr legacy_allocator(const legacy_allocator<U>&) noexcept {}

      T* allocate(std::size_t n, cudaStream_t stream = 0) const {
          T* ptr = 0;
          rmmError_t result = RMM_ALLOC( (void**)&ptr, n*sizeof(T), stream ); 
          if( RMM_SUCCESS != result || nullptr == ptr ) 
          {
            std::cerr << "ERROR: RMM call in line " << __LINE__ << "of file " 
                      << __FILE__ << " failed with result " << rmmGetErrorString(result) 
                      << " (" << result << ") "
                      << " Attempted to allocate: " << n * sizeof(T) << " bytes.\n";
            throw std::bad_alloc();
          }

          return ptr;
      }

      void deallocate(T* p, std::size_t, cudaStream_t stream = 0) const {
          rmmError_t result = RMM_FREE(p, stream);
          if ( RMM_SUCCESS != result) throw std::runtime_error("legacy_allocator: RMM Memory Manager Error");
      }
};

template <class T, class U>
bool operator==(const legacy_allocator<T>&, const legacy_allocator<U>&) { return true; }
template <class T, class U>
bool operator!=(const legacy_allocator<T>&, const legacy_allocator<U>&) { return false; }

#endif
