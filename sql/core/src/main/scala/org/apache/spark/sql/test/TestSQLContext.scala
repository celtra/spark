/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.spark.sql.test

import org.apache.spark.sql.{SQLConf, SQLContext}
import org.apache.spark.{SparkConf, SparkContext}

/** A SQLContext that can be used for local testing. */
object TestSQLContext
  extends SQLContext(
    new SparkContext(
      "local[2]",
      "TestSQLContext",
      new SparkConf().set("spark.sql.testkey", "true"))) {

  /** Fewer partitions to speed up testing. */
  override private[spark] def numShufflePartitions: Int =
    getConf(SQLConf.SHUFFLE_PARTITIONS, "5").toInt
}
