//
//  CollectionUtils.java
//
//  Lunar Unity Mobile Console
//  https://github.com/SpaceMadness/lunar-unity-console
//
//  Copyright 2015-2020 Alex Lementuev, SpaceMadness.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


package spacemadness.com.lunarconsole.utils;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.List;

public class CollectionUtils {
    public static <T> int indexOf(T[] array, T value) {
        for (int i = 0; i < array.length; ++i) {
            if (array[i] == value) {
                return i;
            }
        }
        return -1;
    }

    public static <In, Out> Out[] map(In[] in, MapFunction<In, Out> map) {
        Out[] out = null;
        for (int i = 0; i < in.length; ++i) {
            Out value = map.map(in[i]);
            if (out == null) {
                //noinspection unchecked
                out = (Out[]) Array.newInstance(value.getClass(), in.length);
            }
            out[i] = value;
        }

        return out;
    }

    public static <In, Out> List<Out> map(List<In> in, MapFunction<In, Out> map) {
        List<Out> out = new ArrayList<>(in.size());
        for (int i = 0; i < in.size(); ++i) {
            out.add(map.map(in.get(i)));
        }

        return out;
    }

    public static <T> List<T> merge(List<List<T>> list) {
        List<T> result = new ArrayList<>();
        for (List<T> l : list) {
            result.addAll(l);
        }
        return result;
    }

    public static <T> List<T> listOf(T element, int size) {
        List<T> list = new ArrayList<>(size);
        for (int i = 0; i < size; ++i) {
            list.add(element);
        }
        return list;
    }

    public interface MapFunction<In, Out> {
        Out map(In in);
    }
}